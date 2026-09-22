package design.aem.core.search;

import design.aem.core.service.ElasticSearchHostConfiguration;
import org.osgi.service.component.annotations.Activate;
import org.osgi.service.component.annotations.Component;
import org.osgi.service.component.annotations.Reference;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import javax.net.ssl.SSLContext;
import javax.net.ssl.SSLParameters;
import javax.net.ssl.TrustManager;
import javax.net.ssl.X509TrustManager;
import java.net.URI;
import java.net.http.HttpClient;
import java.security.SecureRandom;
import java.security.cert.X509Certificate;
import java.time.Duration;

@Component(service = ElasticSearchClientProvider.class, immediate = true)
public class ElasticSearchClientProvider {

    private static final Logger LOG = LoggerFactory.getLogger(ElasticSearchClientProvider.class);

    @Reference
    private ElasticSearchHostConfiguration hostConfiguration;

    private HttpClient httpClient;
    private URI baseUri;

    public HttpClient getHttpClient() {
        return httpClient;
    }

    public URI getBaseUri() {
        return baseUri;
    }

    @Activate
    protected void activate() {
        try {
            baseUri = new URI(
                    hostConfiguration.getProtocol(),
                    null,
                    hostConfiguration.getHost(),
                    hostConfiguration.getPort(),
                    null,
                    null,
                    null
            );

            HttpClient.Builder builder = HttpClient.newBuilder()
                    .connectTimeout(Duration.ofSeconds(15))
                    .followRedirects(HttpClient.Redirect.NEVER);

            if (hostConfiguration.isInsecure()) {
                builder.sslContext(createInsecureSslContext());
                SSLParameters sslParameters = new SSLParameters();
                sslParameters.setEndpointIdentificationAlgorithm(null);
                builder.sslParameters(sslParameters);
            }

            httpClient = builder.build();
        } catch (Exception e) {
            LOG.error("Failed to initialize Elasticsearch HttpClient", e);
            throw new IllegalStateException("Failed to initialize Elasticsearch HttpClient", e);
        }
    }

    private SSLContext createInsecureSslContext() throws Exception {
        TrustManager[] trustAllManagers = new TrustManager[]{
                new X509TrustManager() {
                    @Override
                    public void checkClientTrusted(X509Certificate[] chain, String authType) {
                    }

                    @Override
                    public void checkServerTrusted(X509Certificate[] chain, String authType) {
                    }

                    @Override
                    public X509Certificate[] getAcceptedIssuers() {
                        return new X509Certificate[0];
                    }
                }
        };
        SSLContext sslContext = SSLContext.getInstance("TLS");
        sslContext.init(null, trustAllManagers, new SecureRandom());
        return sslContext;
    }
}
