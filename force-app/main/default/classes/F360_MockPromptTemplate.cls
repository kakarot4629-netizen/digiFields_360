@isTest
public class F360_MockPromptTemplate implements HttpCalloutMock {
  private String scenario;
  public F360_MockPromptTemplate(String scenario) {
    this.scenario = scenario;
  }
  public HTTPResponse respond(HTTPRequest request) {
    HttpResponse response = new HttpResponse();
    response.setHeader('Content-Type', 'application/json');
    response.setStatusCode(200);
    response.setBody(
      '{"generations":[{"text":"Test AI response for scenario: ' +
        scenario +
        '"}]}'
    );
    return response;
  }
}
