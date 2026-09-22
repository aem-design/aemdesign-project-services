# Sample AEM project template

This is a project template for AEM-based applications. It is intended as a best-practice set of examples as well as a potential starting point to develop your own functionality.

## Modules

The main parts of the template are:

* core: Java bundle containing all core functionality like OSGi services, listeners or schedulers, as well as component-related Java code such as servlets or request filters.
* it.tests: Java based integration tests
* ui.apps: contains the /apps (and /etc) parts of the project, ie JS&CSS clientlibs, components, and templates
* ui.content: contains sample content using the components from the ui.apps
* ui.config: contains runmode specific OSGi configs for the project
* ui.frontend: an optional dedicated front-end build mechanism (Angular, React or general Webpack project)
* ui.tests: Selenium based UI tests
* all: a single content package that embeds all of the compiled modules (bundles and content packages) including any vendor dependencies
* analyse: this module runs analysis on the project which provides additional validation for deploying into AEMaaCS

## How to build

To build all the modules run in the project root directory the following command with Maven 3:

    mvn clean install

To build all the modules and deploy the `all` package to a local instance of AEM, run in the project root directory the following command:

    mvn clean install -PautoInstallSinglePackage

Or to deploy it to a publish instance, run

    mvn clean install -PautoInstallSinglePackagePublish

Or alternatively

    mvn clean install -PautoInstallSinglePackage -Daem.port=4503

Or to deploy only the bundle to the author, run

    mvn clean install -PautoInstallBundle

Or to deploy only a single content package, run in the sub-module directory (i.e `ui.apps`)

    mvn clean install -PautoInstallPackage

## Testing

There are three levels of testing contained in the project:

### Unit tests

This show-cases classic unit testing of the code contained in the bundle. To
test, execute:

    mvn clean test

### Integration tests

This allows running integration tests that exercise the capabilities of AEM via
HTTP calls to its API. To run the integration tests, run:

    mvn clean verify -Plocal

Test classes must be saved in the `src/main/java` directory (or any of its
subdirectories), and must be contained in files matching the pattern `*IT.java`.

The configuration provides sensible defaults for a typical local installation of
AEM. If you want to point the integration tests to different AEM author and
publish instances, you can use the following system properties via Maven's `-D`
flag.

| Property | Description | Default value |
| --- | --- | --- |
| `it.author.url` | URL of the author instance | `http://localhost:4502` |
| `it.author.user` | Admin user for the author instance | `admin` |
| `it.author.password` | Password of the admin user for the author instance | `admin` |
| `it.publish.url` | URL of the publish instance | `http://localhost:4503` |
| `it.publish.user` | Admin user for the publish instance | `admin` |
| `it.publish.password` | Password of the admin user for the publish instance | `admin` |

The integration tests in this archetype use the [AEM Testing
Clients](https://github.com/adobe/aem-testing-clients) and showcase some
recommended [best
practices](https://github.com/adobe/aem-testing-clients/wiki/Best-practices) to
be put in use when writing integration tests for AEM.

## Static Analysis

The `analyse` module performs static analysis on the project for deploying into AEMaaCS. It is automatically
run when executing

    mvn clean install

from the project root directory. Additional information about this analysis and how to further configure it
can be found here https://github.com/adobe/aemanalyser-maven-plugin

### UI tests

They will test the UI layer of your AEM application using Selenium technology. 

To run them locally:

    mvn clean verify -Pui-tests-local-execution

This default command requires:
* an AEM author instance available at http://localhost:4502 (with the whole project built and deployed on it, see `How to build` section above)
* Chrome browser installed at default location

Check README file in `ui.tests` module for more details.

## ClientLibs

The frontend module is made available using an [AEM ClientLib](https://helpx.adobe.com/experience-manager/6-5/sites/developing/using/clientlibs.html). When executing the NPM build script, the app is built and the [`aem-clientlib-generator`](https://github.com/wcm-io-frontend/aem-clientlib-generator) package takes the resulting build output and transforms it into such a ClientLib.

A ClientLib will consist of the following files and directories:

- `css/`: CSS files which can be requested in the HTML
- `css.txt` (tells AEM the order and names of files in `css/` so they can be merged)
- `js/`: JavaScript files which can be requested in the HTML
- `js.txt` (tells AEM the order and names of files in `js/` so they can be merged
- `resources/`: Source maps, non-entrypoint code chunks (resulting from code splitting), static assets (e.g. icons), etc.

## Maven settings

The project comes with the auto-public repository configured. To setup the repository in your Maven settings, refer to:

    http://helpx.adobe.com/experience-manager/kb/SetUpTheAdobeMavenRepository.html

## Run AEM

To start the full stack run the following command:

```bash
./start.ps1
```

This will start full stack and you can access project dashboard at [https://dashboard.localhost/](https://dashboard.localhost/).

### DevOps helpers

These scripts are the main local SaaS-style operations helpers for this project:

- `./start.ps1` starts the stack and opens the dashboard
- `./stop.ps1` stops the running stack without deleting data
- `./status.ps1` shows compose service state, health, ports, and the key local URLs
- `./logs.ps1` tails compose logs for one or more services, with aliases like `search`, `web`, and `all`
- `./open.ps1` opens the current dashboard, author, publish, dispatcher, Kibana, Traefik, or Elasticsearch URL
- `./verify.ps1` checks author, Elasticsearch, and then runs the Elasticsearch proxy smoke test
- `./restart.dispatcher.ps1` rebuilds just the `dashboard` and `dispatcher` runtime path
- `./reset.ps1` shuts the stack down and optionally prunes Docker resources and project volumes
- `./clean.ps1` previews untracked generated files under `services` and `logs`
- `./clean.ps1 -CLEAN` removes untracked generated files under `services` and `logs`

The local stack now also includes the copied DevOps observability services from the existing project:

- Elasticsearch
- Kibana
- Filebeat
- Metricbeat
- Logstash
- `services/aem/wait-for-aem.sh`

Notes:

- `docker-compose-aem.yml` now respects the Traefik flags defined in `.env` instead of hardcoding them.
- `dashboardbuild` is a one-shot builder service and no longer runs privileged.
- `logstash` is currently configured as a batch-style ingestion job because `services/logstash/logstash.conf` uses `exit_after_read => true`.
- local operator scripts now load `.env.local` automatically when present, so machine-specific port and secret overrides can stay out of the committed `.env`

### Verify Elasticsearch Proxy

Use the local smoke test to verify the AEM proxy endpoint and Elasticsearch are wired correctly end to end.

Default local author on `4502`:

```powershell
./smoke-elasticsearch-proxy.ps1
```

If you are running the alternate-port author used during local verification, point the script at that author explicitly:

```powershell
./smoke-elasticsearch-proxy.ps1 -AemHost http://localhost:14512
```

What this verifies:

- direct Elasticsearch access on `https://localhost:9200`
- test index creation or reuse
- test document write
- AEM proxy metadata read at `/bin/elasticsearch.json/<index>`
- AEM proxy `POST` search at `/bin/elasticsearch.json/<index>/_search`

Expected successful ending:

```text
Smoke test passed.
```

For a higher-level local verification pass that checks author, Elasticsearch, and then runs the smoke test:

```powershell
./verify.ps1
```

Alternate-port author example:

```powershell
./verify.ps1 -AemHost http://localhost:14512
```

To see the current compose service state and the main local URLs:

```powershell
./status.ps1
```

To tail logs for the default local author service:

```powershell
./logs.ps1
```

To tail logs for the search stack or everything in the compose project:

```powershell
./logs.ps1 search -Follow
./logs.ps1 all -Tail 100
```

To keep local-only port or secret overrides out of the committed `.env`, copy `.env.local.example` to `.env.local` and set your machine-specific values there. The local helper scripts and compose commands launched through them will pick those overrides up automatically.

To open the current dashboard or one of the runtime URLs:

```powershell
./open.ps1
./open.ps1 author
./open.ps1 all
```

### Install Content Packages

Firstly get content from Dev environment and put it into `_packages` folder then update `package-install.txt` with file you have.

Default expected files are:

- ./_packages/dev-dam.zip
- ./_packages/dev-sites.zip

Then run the install script to install to both Author and Publish.

```powershell
./install-packages.ps1
```

### Add local Certificate Authority to browser

While containers are starting you can install `services/traefik/certs/mkcert.pfx` as a trusted root certificate in your browser.

1. Double-click on the `services/traefik/certs/mkcert.pfx` certificate file
2. Store Location: `Current User`
3. Click Next
4. Password: `123`
5. Certificate Store: Select Place all certificates in the following store, click Browse and pick `Trusted Root Certification Authorities`
6. Click next
7. Click finish

If you import this into wrong place you can remove it from there and import it again. OR. Quicker way is to recreate certificates by removing files from `services/traefik/certs/mkcert.*`, `services/traefik/certs/rootCA.*` and running:

```powershell
docker compose up createcert
````

### Update replication agent

On author update replication agent, so that you can

1. Open https://author.localhost/etc/replication/agents.author/publish.html
2. On Settings tab
  * Tick enabled
  * Set Agent User Id to `admin`
3. On Transport tab
  * Set URI to `http://publish:8080/bin/receive?sling:authRequestLogin=1`
  * Update user to `admin` and password to `admin`
4. Click test connection and make sure it is successful, check for `Replication test succeeded` message.

### Deploy local codebase

Once aenm stack is started deploy all code to author and publish:

```bash 

```powershell
./deploy.all.ps1
```

### Reset stack

If you want to clear your stack and start from scratch run:

```powershell
./reset.ps1
```

This will stop stack remove all registered containers and clear all docker volumes.

## Push to Adobe SaaS

This step is optional if you are using your own git to manage code updates. In this setup you will be doing all development on your own git and push to Adobe when you are ready. For many reasons pushing from a developers desktop to Adobe SaaS not a best practice, but if you need to push to Adobe SaaS you can do it. 

For best practice you should use CI/CD pipeline to push to Adobe SaaS after you have merged your PR into master or develop branch.

On your local before pushing to Adobe SaaS you need to add remotes for your environment.

```powershell
git remote add develop_adobe https://${GIT_REPO_ADOBE_AUTH}git.cloudmanager.adobe.com/${ADOBE_PROGRAM_NAME}/${ADOBE_PROGRAM_LOCATION}/
git remote add master_adobe https://${GIT_REPO_ADOBE_AUTH}git.cloudmanager.adobe.com/${ADOBE_PROGRAM_NAME}/${ADOBE_PROGRAM_LOCATION}/
```

To push the project to Adobe SaaS, run the following command:

```powershell
./push-develop.ps1
```

## Update Project version

Version numbers should be following semantic versioning.

Please follow [Semantic Versioning 2.0.0](https://semver.org/) for versioning.

For ease of use we are using following format for versioning:

```text
{year}.{month}.{day}-SNAPSHOT
```

`year` is the current year, `month` is the current month and `day` is the current day.
`SNAPSHOT` is the default suffix this ensures that when this package is installed it will be activated by OSGI as the latest version.

The version is not relevant for the project itself as artifacts will be used in a containerized environment and this project is not deployed to any Maven repository.

To update version of the project run:

```powershell
mvn versions:set -DnewVersion="2023.5.2-SNAPSHOT"  
```

Run the following after to generate new version of the project:

```powershell
mvn clean install
```

## Generate This project

```powershell
mvn -B org.apache.maven.plugins:maven-archetype-plugin:3.2.1:generate -D archetypeGroupId=com.adobe.aem -D archetypeArtifactId=aem-project-archetype -D archetypeVersion=43 -D appTitle="AEM.Design" -D appId="aemdesign" -D groupId="design.aem" -D aemVersion=cloud -D country=au -D singleCountry=n -D includeExamples=y -D includeErrorHandler=y
```

If you get an error like:

```text
[ERROR] groovy.lang.GroovyRuntimeException: Conflicting module versions. Module [groovy-all is loaded in version 2.4.16 and you are trying to load version 2.4.8
```

Run the following to ensure you have the correct version of Groovy:

```powershell
mvn org.apache.maven.plugins:maven-dependency-plugin:2.1:get -DrepoUrl=https://repo.maven.apache.org/maven2/ -Dartifact=org.codehaus.groovy:groovy-all:2.4.8
```

Then update `%USERPROFILE%\.m2\repository\org\apache\maven\archetype\archetype-common\3.2.1\archetype-common-3.2.1.pom` by updating `groovy-all` dependency to version `2.4.8`:

```xml
<dependency>
  <groupId>org.codehaus.groovy</groupId>
  <artifactId>groovy-all</artifactId>
  <version>2.4.8</version>
  <scope>compile</scope>
</dependency>
```

## Environment Configuration

Following configurations should be updated for your project. These configurations are used in the dashboard page to display the project information.

You can get all this information from the Adobe Developer or Adobe Experience consoles.

### Project Config

This configuration is used to construct project URL's in the [Console Config](#console-config) section.

```dotenv
ADOBE_PROGRAM_ID="99999"
ADOBE_PROGRAM_REGION_ID="99999"
ADOBE_PROGRAM_ENVIRONMENT_PROD_ID="999991"
ADOBE_PROGRAM_ENVIRONMENT_STAGE_ID="999992"
ADOBE_PROGRAM_ENVIRONMENT_DEV_ID="999993"
ADOBE_PROGRAM_NAME="aemdesign"
ADOBE_PROGRAM_LOCATION="AEMDESIGN-p${ADOBE_PROGRAM_ID}-${ADOBE_PROGRAM_REGION_ID}"
ADOBE_PROGRAM_TITLE="AEM.Design"
ADOBE_PROGRAM_DESCRIPTION="AEM.Design"
ADOBE_PROGRAM_URL="https://aem.design"
```

### Console Config

These are the console links for the project, they are displayed in the dashboard page, will enable you to quickly navigate to the console pages for the project.

```dotenv
# Console Config
ADOBE_CONSOLE_EXPERIENCE_URL="https://experience.adobe.com/#/@${ADOBE_PROGRAM_NAME}/cloud-manager/environments.html/program/${ADOBE_PROGRAM_ID}"
ADOBE_CONSOLE_EXPERIENCE_URL_ICON="fab fa-adobe"
ADOBE_CONSOLE_EXPERIENCE_URL_TITLE="Cloud Manager"

ADOBE_CONSOLE_DEVELOPER_URL="https://developer.adobe.com/console/home"
ADOBE_CONSOLE_DEVELOPER_URL_ICON="fab fa-adobe"
ADOBE_CONSOLE_DEVELOPER_URL_TITLE="Developer Console"

ADOBE_CONSOLE_ADMIN_URL="https://adminconsole.adobe.com/"
ADOBE_CONSOLE_ADMIN_URL_ICON="fab fa-adobe"
ADOBE_CONSOLE_ADMIN_URL_TITLE="Admin Console"

# format: <URL>|<TITLE>|<ICON>
CONSOLE_LINKS="${ADOBE_CONSOLE_EXPERIENCE_URL}|${ADOBE_CONSOLE_EXPERIENCE_URL_TITLE}|${ADOBE_CONSOLE_EXPERIENCE_URL_ICON},${ADOBE_CONSOLE_DEVELOPER_URL}|${ADOBE_CONSOLE_DEVELOPER_URL_TITLE}|${ADOBE_CONSOLE_DEVELOPER_URL_ICON},${ADOBE_CONSOLE_ADMIN_URL}|${ADOBE_CONSOLE_ADMIN_URL_TITLE}|${ADOBE_CONSOLE_ADMIN_URL_ICON}"
```

### Page and Showcase Links

When developing or testing the project, you typically want to navigate to the home page or showcase page. This allows you to configure any commonly used quick links. Update `PAGE_LINKS` with link you want to use on regular basis.

Typically you would want to add links to each homepage for every site you will be working on. Furthermore you should have a sister showcase site for each of your live sites, updating `SHOWCASE_LINKS` will add additional row of links matching your `PAGE_LINKS` links. 

These links are displayed in the dashboard page.

```dotenv
# format: <URL>|<TITLE>|<ICON>|<DISPATCHER SUBDOMAIN>
PAGE_LINKS="/content/aemdesign/home.html|AEM.Design - Home|fa fa-globe|aemdesign"
SHOWCASE_LINKS="/content/aemdesign-showcase.html/|AEM.Design - Showcase|fa-globe|aemdesign"
```

### Environment Link

These are the environment links for the project, they are displayed in the dashboard page, will enable you to quickly navigate to the environment pages for the project. By default this is configured to basic PROD, STAGE and DEV environments. Update this to match all of your provisioned environments.

```dotenv

ADOBE_PROGRAM_ENVIRONMENT_PROD_URL="https://author-p${ADOBE_PROGRAM_ID}-e${ADOBE_PROGRAM_ENVIRONMENT_PROD_ID}.adobeaemcloud.com/"
ADOBE_PROGRAM_ENVIRONMENT_PROD_TITLE="Prod"
ADOBE_PROGRAM_ENVIRONMENT_PROD_ICON="fa fa-globe"

ADOBE_PROGRAM_ENVIRONMENT_STAGE_URL="https://author-p${ADOBE_PROGRAM_ID}-e${ADOBE_PROGRAM_ENVIRONMENT_STAGE_ID}.adobeaemcloud.com/"
ADOBE_PROGRAM_ENVIRONMENT_STAGE_TITLE="Stage"
ADOBE_PROGRAM_ENVIRONMENT_STAGE_ICON="fa fa-globe"

ADOBE_PROGRAM_ENVIRONMENT_DEV_URL="https://author-p${ADOBE_PROGRAM_ID}-e${ADOBE_PROGRAM_ENVIRONMENT_DEV_ID}.adobeaemcloud.com/"
ADOBE_PROGRAM_ENVIRONMENT_DEV_TITLE="Dev"
ADOBE_PROGRAM_ENVIRONMENT_DEV_ICON="fa fa-globe"

# format: <URL>|<TITLE>|<ICON>
AUTHOR_LINKS="${ADOBE_PROGRAM_ENVIRONMENT_PROD_URL}|${ADOBE_PROGRAM_ENVIRONMENT_PROD_TITLE}|${ADOBE_PROGRAM_ENVIRONMENT_PROD_ICON},${ADOBE_PROGRAM_ENVIRONMENT_STAGE_URL}|${ADOBE_PROGRAM_ENVIRONMENT_STAGE_TITLE}|${ADOBE_PROGRAM_ENVIRONMENT_STAGE_ICON},${ADOBE_PROGRAM_ENVIRONMENT_DEV_URL}|${ADOBE_PROGRAM_ENVIRONMENT_DEV_TITLE}|${ADOBE_PROGRAM_ENVIRONMENT_DEV_ICON}"

```

### Git Config

This configuration is used for Git links.

```dotenv
# Git Config
#GIT_REPO_AUTH="<username>:<password>@"  # set this in your terminal
GIT_REPO_AUTH=""
GIT_REPO="https://${GIT_REPO_AUTH}github.com/aem-design/aemdesign-project-services.git"
GIT_REPO_ICON="fa-github" #fa-github,fa-bitbucket
GIT_REPO_TITLE="Github"
#GIT_REPO_ADOBE_AUTH="<username>:<password>@" # set this in your terminal
GIT_REPO_ADOBE_AUTH=""
GIT_REPO_ADOBE="https://${GIT_REPO_ADOBE_AUTH}git.cloudmanager.adobe.com/${ADOBE_PROGRAM_NAME}/${ADOBE_PROGRAM_LOCATION}/ "
GIT_REPO_ADOBE_ICON="fa-adobe"
GIT_REPO_ADOBE_TITLE="Adobe Git"
```

## Files

- .env (environment variables auto loaded by functions.ps1)
- .gitignore (git ignore file)
- deploy-apps.ps1 (only deplopy apps module)
- deploy.all.ps1 (deploy all packages as single package to author and publish)
- deploy.frontend.ps1 (only deploy apps and frontend module)
- deploy.ps1 (deploy script)
- dev-token.json (json file with your Adobe IMS token)
- docker-compose.yml (entry point; includes docker-compose-aem.yml + docker-compose-elasticsearch.yml)
- functions.ps1 (helper functions)
- install_packages.ps1 (auto install packages to author and publish using package.ps1)
- local-token.txt (text file with admin:admin in base64)
- package-install.txt (list of packages to auto install)
- package.ps1 (papckage install script)
- push-develop.ps1 (pushes to adobe saas remote develop branch)
- README.md (additional information about the project)
- reset.ps1 (resets the project by deleting all volumes and containers)
- start.ps1 (starts the doscker stack)

### Dispatcher file

Update these files to match your project, make new files for each vhost where relevant.

- dispatcher/src/conf.d/available_vhosts/default.vhost (customize for each vhost you have)
- dispatcher/src/conf.d/variables/custom.vars (one place for all of your variables)
- dispatcher/src/conf.d/rewrites/rewrite.rules (customize for each vhost you have)
- dispatcher/src/conf.dispatcher.d/filters/filters.any (customize for each vhost you have)
- dispatcher/src/conf.dispatcher.d/available_farms/default.farm ( for SaaS you don't need to modify, customize for each farm you have)
- dispatcher/scripts/fix-symlinks.sh (add each enabled vhost and farm)
