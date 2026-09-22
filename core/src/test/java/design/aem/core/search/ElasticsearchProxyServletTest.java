package design.aem.core.search;

import design.aem.core.service.ElasticSearchHostConfiguration;
import org.apache.sling.api.SlingHttpServletRequest;
import org.apache.sling.api.request.RequestPathInfo;
import org.apache.sling.testing.mock.sling.servlet.MockSlingHttpServletResponse;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;

import javax.servlet.ReadListener;
import javax.servlet.ServletInputStream;
import java.io.ByteArrayInputStream;
import java.io.IOException;
import java.lang.reflect.Field;
import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.nio.charset.StandardCharsets;
import java.util.Base64;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

class ElasticsearchProxyServletTest {

    private final ElasticsearchProxyServlet fixture = new ElasticsearchProxyServlet();
    private final ElasticSearchClientProvider clientProvider = mock(ElasticSearchClientProvider.class);
    private final ElasticSearchHostConfiguration hostConfiguration = mock(ElasticSearchHostConfiguration.class);
    private final HttpClient httpClient = mock(HttpClient.class);

    @BeforeEach
    void setUp() throws Exception {
        injectField(fixture, "clientProvider", clientProvider);
        injectField(fixture, "hostConfiguration", hostConfiguration);

        when(clientProvider.getHttpClient()).thenReturn(httpClient);
        when(clientProvider.getBaseUri()).thenReturn(URI.create("https://elasticsearch:9200"));
        when(hostConfiguration.getAuthType()).thenReturn("basic");
        when(hostConfiguration.getUsername()).thenReturn("elastic");
        when(hostConfiguration.getPassword()).thenReturn("elastic");
        when(hostConfiguration.getApiKey()).thenReturn("");
        when(hostConfiguration.getAllowedSearchProxyGetPatterns()).thenReturn(new String[]{
                "^(aem-saas-site-content|aem-saas-site-content-test)$",
                "^(aem-saas-site-content|aem-saas-site-content-test)/_doc/[\\w/-]+$"
        });
        when(hostConfiguration.getAllowedSearchProxyPostPatterns()).thenReturn(new String[]{
                "^(aem-saas-site-content|aem-saas-site-content-test)/_search.*$"
        });
    }

    @Test
    void doGetRejectsBlockedPath() throws Exception {
        SlingHttpServletRequest request = mockRequest("GET", "/aem-saas-site-content-test/_search", null, null, null);
        MockSlingHttpServletResponse response = new MockSlingHttpServletResponse();

        fixture.service(request, response);

        assertEquals(403, response.getStatus());
        assertEquals("{\"error\":\"Access denied to path: aem-saas-site-content-test/_search\"}",
                response.getOutputAsString());
        verify(httpClient, never()).send(any(), any(HttpResponse.BodyHandler.class));
    }

    @Test
    void doGetProxiesAllowedRequest() throws Exception {
        HttpResponse<byte[]> esResponse = mockHttpResponse(200,
                "{\"status\":\"ok\"}".getBytes(StandardCharsets.UTF_8));
        when(httpClient.send(any(HttpRequest.class), any(HttpResponse.BodyHandler.class))).thenReturn(esResponse);

        SlingHttpServletRequest request = mockRequest(
                "GET",
                "/aem-saas-site-content-test",
                "pretty=true",
                null,
                null
        );
        MockSlingHttpServletResponse response = new MockSlingHttpServletResponse();

        fixture.service(request, response);

        ArgumentCaptor<HttpRequest> requestCaptor = ArgumentCaptor.forClass(HttpRequest.class);
        verify(httpClient).send(requestCaptor.capture(), any(HttpResponse.BodyHandler.class));

        HttpRequest outbound = requestCaptor.getValue();
        assertEquals(URI.create("https://elasticsearch:9200/aem-saas-site-content-test?pretty=true"), outbound.uri());
        assertEquals("Basic " + Base64.getEncoder().encodeToString("elastic:elastic".getBytes(StandardCharsets.UTF_8)),
                outbound.headers().firstValue("Authorization").orElse(""));
        assertEquals(200, response.getStatus());
        assertEquals("{\"status\":\"ok\"}", response.getOutputAsString());
    }

    @Test
    void doPostProxiesAllowedSearch() throws Exception {
        HttpResponse<byte[]> esResponse = mockHttpResponse(200,
                "{\"hits\":{\"total\":{\"value\":1}}}".getBytes(StandardCharsets.UTF_8));
        when(httpClient.send(any(HttpRequest.class), any(HttpResponse.BodyHandler.class))).thenReturn(esResponse);

        SlingHttpServletRequest request = mockRequest(
                "POST",
                "/aem-saas-site-content-test/_search",
                null,
                "application/json",
                "{\"query\":{\"match\":{\"title\":\"hello\"}}}"
        );
        MockSlingHttpServletResponse response = new MockSlingHttpServletResponse();

        fixture.service(request, response);

        ArgumentCaptor<HttpRequest> requestCaptor = ArgumentCaptor.forClass(HttpRequest.class);
        verify(httpClient).send(requestCaptor.capture(), any(HttpResponse.BodyHandler.class));

        HttpRequest outbound = requestCaptor.getValue();
        assertEquals("POST", outbound.method());
        assertEquals(URI.create("https://elasticsearch:9200/aem-saas-site-content-test/_search"), outbound.uri());
        assertEquals("application/json", outbound.headers().firstValue("Content-Type").orElse(""));
        assertEquals(200, response.getStatus());
        assertTrue(response.getOutputAsString().contains("\"value\":1"));
    }

    @Test
    void doGetReturnsProxyErrorWhenClientUnavailable() throws Exception {
        when(clientProvider.getHttpClient()).thenReturn(null);

        SlingHttpServletRequest request = mockRequest("GET", "/aem-saas-site-content-test", null, null, null);
        MockSlingHttpServletResponse response = new MockSlingHttpServletResponse();

        fixture.service(request, response);

        assertEquals(500, response.getStatus());
        assertTrue(response.getOutputAsString().contains("HttpClient not available"));
    }

    private SlingHttpServletRequest mockRequest(String method, String suffix, String queryString, String contentType, String body)
            throws IOException {
        SlingHttpServletRequest request = mock(SlingHttpServletRequest.class);
        RequestPathInfo pathInfo = mock(RequestPathInfo.class);
        when(pathInfo.getSuffix()).thenReturn(suffix);
        when(request.getRequestPathInfo()).thenReturn(pathInfo);
        when(request.getMethod()).thenReturn(method);
        when(request.getQueryString()).thenReturn(queryString);
        when(request.getContentType()).thenReturn(contentType);
        when(request.getInputStream()).thenReturn(servletInputStream(body));
        return request;
    }

    private HttpResponse<byte[]> mockHttpResponse(int status, byte[] body) {
        HttpResponse<byte[]> response = mock(HttpResponse.class);
        when(response.statusCode()).thenReturn(status);
        when(response.body()).thenReturn(body);
        return response;
    }

    private ServletInputStream servletInputStream(String body) {
        ByteArrayInputStream inputStream = new ByteArrayInputStream(
                body == null ? new byte[0] : body.getBytes(StandardCharsets.UTF_8)
        );
        return new ServletInputStream() {
            @Override
            public boolean isFinished() {
                return inputStream.available() == 0;
            }

            @Override
            public boolean isReady() {
                return true;
            }

            @Override
            public void setReadListener(ReadListener readListener) {
            }

            @Override
            public int read() {
                return inputStream.read();
            }
        };
    }

    private void injectField(Object target, String fieldName, Object value) throws Exception {
        Field field = target.getClass().getDeclaredField(fieldName);
        field.setAccessible(true);
        field.set(target, value);
    }
}
