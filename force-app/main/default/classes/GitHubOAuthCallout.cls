public class GitHubOAuthCallout {
    public static void callGitHub(){
        HttpRequest request = new HttpRequest();
        request.setEndpoint('callout:GitHub_OAuth'+'/users/kkinene/repos');
        request.setMethod('GET');
        request.setHeader('Accept', 'application/json');
        Http http = new Http();
        HTTPResponse res = http.send(request);
        System.debug('Status Code: ' + res.getStatusCode());
        System.debug('Response Body: ' + res.getBody());
    }
}