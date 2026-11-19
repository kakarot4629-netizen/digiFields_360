@IsTest
private class DF360_AuthAPITest {
    @IsTest
    static void testGetMe() {
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/df360/v1/auth/me';
        req.httpMethod = 'GET';
        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        DF360_AuthAPI.doGet();
        Test.stopTest();

        System.assertEquals(200, res.statusCode);
        Map<String, Object> respMap = (Map<String, Object>) JSON.deserializeUntyped(res.responseBody.toString());
        System.assertEquals(true, respMap.get('success'));
        System.assertNotEquals(null, respMap.get('user'));
    }
}