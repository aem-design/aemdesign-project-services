package design.aem.core.search;

import design.aem.core.service.ElasticSearchHostConfiguration;
import org.junit.jupiter.api.Test;

import java.lang.reflect.Field;
import java.net.URI;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

class ElasticSearchClientProviderTest {

    @Test
    void activateBuildsBaseUriAndClient() throws Exception {
        ElasticSearchHostConfiguration configuration = mock(ElasticSearchHostConfiguration.class);
        when(configuration.getProtocol()).thenReturn("https");
        when(configuration.getHost()).thenReturn("elasticsearch");
        when(configuration.getPort()).thenReturn(9200);
        when(configuration.isInsecure()).thenReturn(true);

        ElasticSearchClientProvider provider = new ElasticSearchClientProvider();
        injectField(provider, "hostConfiguration", configuration);

        provider.activate();

        assertEquals(URI.create("https://elasticsearch:9200"), provider.getBaseUri());
        assertNotNull(provider.getHttpClient());
    }

    @Test
    void activateSupportsHttpBaseUri() throws Exception {
        ElasticSearchHostConfiguration configuration = mock(ElasticSearchHostConfiguration.class);
        when(configuration.getProtocol()).thenReturn("http");
        when(configuration.getHost()).thenReturn("localhost");
        when(configuration.getPort()).thenReturn(9201);
        when(configuration.isInsecure()).thenReturn(false);

        ElasticSearchClientProvider provider = new ElasticSearchClientProvider();
        injectField(provider, "hostConfiguration", configuration);

        provider.activate();

        assertEquals(URI.create("http://localhost:9201"), provider.getBaseUri());
        assertNotNull(provider.getHttpClient());
        assertTrue(provider.getHttpClient().connectTimeout().isPresent());
    }

    private void injectField(Object target, String fieldName, Object value) throws Exception {
        Field field = target.getClass().getDeclaredField(fieldName);
        field.setAccessible(true);
        field.set(target, value);
    }
}
