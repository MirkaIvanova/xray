$config = {}
$config[:jiraUrl] = 'https://clippings.atlassian.net/rest/api/2/'
$config[:xrayAuthUrl] = 'https://xray.cloud.xpand-it.com/api/v1/authenticate'
$config[:xrayGraphqlUrl] = 'http://xray.cloud.xpand-it.com/api/v1/graphql'

# 1. Generate Jira API Token here: https://id.atlassian.com/manage/api-tokens
# 2. Generate string for Basic Auth:
#     echo -n miroslava@clippings.com:<Jira API Token> | base64
# 3. fill the below value: $config[:jiraAuth] = 'Basic <Basic Auth string>'
$config[:jiraAuth] = 'Basic ...'

# Generate XRay client id and client secret from: Jira settings > Apps > Xray > API Keys
$config[:xrayClientId] = ''
$config[:xrayClientSecret] = ''

