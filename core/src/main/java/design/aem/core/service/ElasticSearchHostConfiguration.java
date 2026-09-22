package design.aem.core.service;

import org.osgi.service.component.annotations.Activate;
import org.osgi.service.component.annotations.Component;
import org.osgi.service.component.annotations.ConfigurationPolicy;
import org.osgi.service.metatype.annotations.AttributeDefinition;
import org.osgi.service.metatype.annotations.Designate;
import org.osgi.service.metatype.annotations.ObjectClassDefinition;
import org.osgi.service.metatype.annotations.Option;

@Component(
        service = ElasticSearchHostConfiguration.class,
        immediate = true,
        configurationPolicy = ConfigurationPolicy.REQUIRE
)
@Designate(ocd = ElasticSearchHostConfiguration.Config.class, factory = true)
public class ElasticSearchHostConfiguration {

    @ObjectClassDefinition(
            name = "AEM.Design Elasticsearch Host Configuration",
            description = "Connection and allow-list settings for the local Elasticsearch proxy"
    )
    public @interface Config {

        @AttributeDefinition(name = "Host", description = "Hostname of the Elasticsearch instance")
        String host() default "localhost";

        @AttributeDefinition(name = "Port", description = "Port of the Elasticsearch instance")
        int port() default 9200;

        @AttributeDefinition(name = "Protocol", description = "Protocol for Elasticsearch")
        String protocol() default "http";

        @AttributeDefinition(
                name = "Web Console Name Hint",
                description = "Shown in the OSGi console to identify this factory config"
        )
        String webconsole_configurationFactory_nameHint() default "Host: {host}";

        @AttributeDefinition(name = "Insecure", description = "Allow insecure HTTPS connections")
        boolean insecure() default false;

        @AttributeDefinition(name = "Username", description = "Username for authentication")
        String username() default "";

        @AttributeDefinition(name = "Password", description = "Password for authentication")
        String password() default "";

        @AttributeDefinition(name = "API Key", description = "API Key for authentication")
        String apiKey() default "";

        @AttributeDefinition(
                name = "Authentication Type",
                description = "Authentication type to use",
                options = {
                        @Option(label = "Basic Authentication", value = "basic"),
                        @Option(label = "API Key", value = "apiKey"),
                        @Option(label = "None", value = "none")
                }
        )
        String authType() default "basic";

        @AttributeDefinition(
                name = "Allowed Search Proxy Post Patterns",
                description = "Allowed POST path patterns for the proxy"
        )
        String[] allowedSearchProxyPostPatterns() default {
                "^(aem-saas-site-content|aem-saas-site-content-test)/_search.*$",
                "^(aem-saas-site-content|aem-saas-site-content-test)/_count.*$",
                "^_search.*$",
                "^_count.*$"
        };

        @AttributeDefinition(
                name = "Allowed Search Proxy Get Patterns",
                description = "Allowed GET path patterns for the proxy"
        )
        String[] allowedSearchProxyGetPatterns() default {
                "^(aem-saas-site-content|aem-saas-site-content-test)/_doc/[\\w/-]+$",
                "^(aem-saas-site-content|aem-saas-site-content-test)/_mapping$",
                "^(aem-saas-site-content|aem-saas-site-content-test)/_settings$",
                "^(aem-saas-site-content|aem-saas-site-content-test)$"
        };
    }

    private String protocol;
    private String host;
    private int port;
    private boolean insecure;
    private String username;
    private String password;
    private String apiKey;
    private String authType;
    private String[] allowedSearchProxyPostPatterns;
    private String[] allowedSearchProxyGetPatterns;

    public String getProtocol() {
        return protocol;
    }

    public String getHost() {
        return host;
    }

    public int getPort() {
        return port;
    }

    public boolean isInsecure() {
        return insecure;
    }

    public String getUsername() {
        return username;
    }

    public String getPassword() {
        return password;
    }

    public String getApiKey() {
        return apiKey;
    }

    public String getAuthType() {
        return authType;
    }

    public String[] getAllowedSearchProxyPostPatterns() {
        return allowedSearchProxyPostPatterns;
    }

    public String[] getAllowedSearchProxyGetPatterns() {
        return allowedSearchProxyGetPatterns;
    }

    @Activate
    protected void activate(Config config) {
        this.host = config.host();
        this.port = config.port();
        this.protocol = config.protocol();
        this.insecure = config.insecure();
        this.username = config.username();
        this.password = config.password();
        this.apiKey = config.apiKey();
        this.authType = config.authType();
        this.allowedSearchProxyPostPatterns = config.allowedSearchProxyPostPatterns();
        this.allowedSearchProxyGetPatterns = config.allowedSearchProxyGetPatterns();
    }
}
