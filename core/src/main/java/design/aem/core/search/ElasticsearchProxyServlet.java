package design.aem.core.search;

import design.aem.core.service.ElasticSearchHostConfiguration;
import org.apache.sling.api.SlingHttpServletRequest;
import org.apache.sling.api.SlingHttpServletResponse;
import org.apache.sling.api.request.RequestPathInfo;
import org.apache.sling.api.servlets.HttpConstants;
import org.apache.sling.api.servlets.SlingAllMethodsServlet;
import org.osgi.service.component.annotations.Component;
import org.osgi.service.component.annotations.Reference;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import javax.servlet.Servlet;
import javax.servlet.ServletException;
import java.io.IOException;
import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.nio.charset.StandardCharsets;
import java.util.Base64;
import java.util.regex.Pattern;

@Component(
        service = Servlet.class,
        property = {
                "sling.servlet.methods=" + HttpConstants.METHOD_GET,
                "sling.servlet.methods=" + HttpConstants.METHOD_POST,
                "sling.servlet.paths=/bin/elasticsearch",
                "sling.servlet.extensions=json"
        },
        immediate = true
)
public class ElasticsearchProxyServlet extends SlingAllMethodsServlet {

    private static final Logger LOG = LoggerFactory.getLogger(ElasticsearchProxyServlet.class);

    @Reference
    private ElasticSearchClientProvider clientProvider;

    @Reference
    private ElasticSearchHostConfiguration hostConfiguration;

    @Override
    protected void service(SlingHttpServletRequest request, SlingHttpServletResponse response)
            throws ServletException, IOException {

        RequestPathInfo pathInfo = request.getRequestPathInfo();
        String elasticPath = pathInfo.getSuffix();
        if (elasticPath == null || elasticPath.length() <= 1) {
            sendError(response, 400, "Elasticsearch path required");
            return;
        }

        String elasticsearchPath = elasticPath.startsWith("/") ? elasticPath.substring(1) : elasticPath;
        String method = request.getMethod();

        if (!isAllowedPath(elasticsearchPath, method)) {
            LOG.warn("Blocked request to unauthorized path: {} {}", method, elasticsearchPath);
            sendError(response, 403, "Access denied to path: " + elasticsearchPath);
            return;
        }

        try {
            HttpClient httpClient = clientProvider.getHttpClient();
            URI baseUri = clientProvider.getBaseUri();
            if (httpClient == null || baseUri == null) {
                throw new IllegalStateException("HttpClient not available");
            }

            HttpRequest.Builder requestBuilder = HttpRequest.newBuilder(
                            buildRequestUri(baseUri, elasticsearchPath, request.getQueryString()))
                    .header("Accept", "application/json")
                    .header("X-Elastic-Product", "Elasticsearch");

            addAuthorizationHeader(requestBuilder);

            if (HttpConstants.METHOD_POST.equals(method)) {
                String contentType = request.getContentType();
                requestBuilder.header("Content-Type", contentType != null ? contentType : "application/json");
                requestBuilder.POST(HttpRequest.BodyPublishers.ofByteArray(request.getInputStream().readAllBytes()));
            } else {
                requestBuilder.GET();
            }

            HttpResponse<byte[]> esResponse = httpClient.send(
                    requestBuilder.build(),
                    HttpResponse.BodyHandlers.ofByteArray()
            );

            response.setStatus(esResponse.statusCode());
            response.setContentType("application/json");
            byte[] body = esResponse.body();
            if (body != null && body.length > 0) {
                response.getOutputStream().write(body);
            }
        } catch (Exception e) {
            LOG.error("Error proxying request to Elasticsearch", e);
            sendError(response, 500, "Proxy error: " + e.getMessage());
        }
    }

    private boolean isAllowedPath(String path, String method) {
        if (!HttpConstants.METHOD_GET.equals(method) && !HttpConstants.METHOD_POST.equals(method)) {
            return false;
        }

        String[] patterns = HttpConstants.METHOD_GET.equals(method)
                ? hostConfiguration.getAllowedSearchProxyGetPatterns()
                : hostConfiguration.getAllowedSearchProxyPostPatterns();

        if (patterns == null || patterns.length == 0) {
            return false;
        }

        for (String patternStr : patterns) {
            try {
                Pattern pattern = Pattern.compile(patternStr);
                if (pattern.matcher(path).matches()) {
                    return true;
                }
            } catch (Exception e) {
                LOG.warn("Invalid regex pattern '{}': {}", patternStr, e.getMessage());
            }
        }
        return false;
    }

    private URI buildRequestUri(URI baseUri, String elasticsearchPath, String queryString) {
        StringBuilder builder = new StringBuilder(baseUri.toString());
        if (!baseUri.toString().endsWith("/")) {
            builder.append('/');
        }
        builder.append(elasticsearchPath);
        if (queryString != null && !queryString.isEmpty()) {
            builder.append('?').append(queryString);
        }
        return URI.create(builder.toString());
    }

    private void addAuthorizationHeader(HttpRequest.Builder requestBuilder) {
        String authType = hostConfiguration.getAuthType();
        if ("basic".equalsIgnoreCase(authType)
                && !hostConfiguration.getUsername().isEmpty()
                && !hostConfiguration.getPassword().isEmpty()) {
            String token = Base64.getEncoder().encodeToString(
                    (hostConfiguration.getUsername() + ":" + hostConfiguration.getPassword())
                            .getBytes(StandardCharsets.UTF_8)
            );
            requestBuilder.header("Authorization", "Basic " + token);
        } else if ("apikey".equalsIgnoreCase(authType) && !hostConfiguration.getApiKey().isEmpty()) {
            requestBuilder.header("Authorization", "ApiKey " + hostConfiguration.getApiKey().trim());
        }
    }

    private void sendError(SlingHttpServletResponse response, int status, String message) throws IOException {
        response.setStatus(status);
        response.setContentType("application/json");
        response.getWriter().write("{\"error\":\"" + message + "\"}");
    }
}
