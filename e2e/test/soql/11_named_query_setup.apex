// 11_named_query_setup.apex
// Commits enough records through SelfREST to force a second Named Query response page.
for (Integer batch = 0; batch < 10; batch++) {
    List<Object> records = new List<Object>();
    for (Integer i = 0; i < 200; i++) {
        records.add(
            new Map<String, Object>{
                'attributes' => new Map<String, Object>{ 'type' => 'Account' },
                'Name' => 'Named Query E2E ' +
                batch +
                '-' +
                i
            }
        );
    }

    HttpRequest request = new HttpRequest();
    request.setEndpoint('callout:SelfREST/services/data/v67.0/composite/sobjects');
    request.setMethod('POST');
    request.setHeader('Content-Type', 'application/json');
    request.setBody(JSON.serialize(new Map<String, Object>{ 'allOrNone' => true, 'records' => records }));

    HttpResponse response = new Http().send(request);
    Assert.isTrue(
        response.getStatusCode() == 200 || response.getStatusCode() == 201,
        'Account setup failed: ' + response.getStatusCode() + ' ' + response.getBody()
    );
}

System.debug('E2E Test 11 Setup Passed');
