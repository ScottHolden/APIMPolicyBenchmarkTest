@description('Location for all resources.')
param location string = resourceGroup().location

@description('A prefix to add to the start of all resource names. Note: A "unique" suffix will also be added')
param prefix string = 'perftest'

@description('Tags to apply to all deployed resources')
param tags object = {}

param apimEmail string = 'noreply@microsoft.com'

param deployTestVm bool = false
param testVmUsername string = 'perftest'
param testVmPublicKey string = ''
param testVmAllowedIp string = ''

var uniqueNameFormat = '${toLower(trim(prefix))}-{0}-${uniqueString(resourceGroup().id, prefix)}'

var ids100csv = loadTextContent('misc/ids_100.csv')
var ids370csv = loadTextContent('misc/ids_370.csv')

var ids100json = loadTextContent('misc/ids_100.json')
var ids370json = loadTextContent('misc/ids_370.json')
var ids1000json = loadTextContent('misc/ids_1000.json')

var inboundPolicyFormat = '''
<policies>
    <inbound>
        {0}
        <base />
    </inbound>
    <backend>
        <base />
    </backend>
    <outbound>
        <base />
    </outbound>
    <on-error>
        <base />
    </on-error>
</policies>'''

var mockIfFoundCSVPolicyFormat = format(inboundPolicyFormat, '''
<set-variable name="IdToCheck" value="@(context.Request.Headers.GetValueOrDefault("X-Client-Id",""))" />
<choose>
    <when condition="@(!context.Variables.ContainsKey("IdToCheck") || string.IsNullOrWhiteSpace((string)context.Variables["IdToCheck"]) || ((string)context.Variables["IdToCheck"]).Length != 8)">
        <return-response>
          <set-status code="400" reason="Bad Request"/>
          <set-body>No Client Id set</set-body>
        </return-response>
    </when>
    <when condition="@("{0}".Split(',').Contains((string)context.Variables["IdToCheck"]))">
        <mock-response status-code="200" content-type="application/json" />
    </when>
</choose>
''')

var mockIfFoundJsonPolicyFormat = format(inboundPolicyFormat, '''
<set-variable name="IdToCheck" value="@(context.Request.Headers.GetValueOrDefault("X-Client-Id",""))" />
<set-variable name="IdJsonArray" value="{0}" />
<choose>
    <when condition="@(!context.Variables.ContainsKey("IdToCheck") || string.IsNullOrWhiteSpace((string)context.Variables["IdToCheck"]) || ((string)context.Variables["IdToCheck"]).Length != 8)">
        <return-response>
          <set-status code="400" reason="Bad Request"/>
          <set-body>No Client Id set</set-body>
        </return-response>
    </when>
    <when condition="@(!context.Variables.ContainsKey("IdJsonArray") || string.IsNullOrWhiteSpace((string)context.Variables["IdJsonArray"]))">
        <return-response>
          <set-status code="500" reason="Server Error"/>
          <set-body>Client Id list empty</set-body>
        </return-response>
    </when>
    <when condition="@(Newtonsoft.Json.JsonConvert.DeserializeObject<string[]>((string)context.Variables["IdJsonArray"])?.Contains((string)context.Variables["IdToCheck"]) ?? false)">
        <mock-response status-code="200" content-type="application/json" />
    </when>
</choose>
''')

var inlinePolicyFragmentFormat = '''
<fragment>
<set-variable name="IdToCheck" value="@(context.Request.Headers.GetValueOrDefault("X-Client-Id",""))" />
<choose>
    <when condition="@(!context.Variables.ContainsKey("IdToCheck") || string.IsNullOrWhiteSpace((string)context.Variables["IdToCheck"]) || ((string)context.Variables["IdToCheck"]).Length != 8)">
        <return-response>
          <set-status code="400" reason="Bad Request"/>
          <set-body>No Client Id set</set-body>
        </return-response>
    </when>
    <when condition="@{{
      string[] ids = new string[] {{ {0} }};
      return ids.Contains((string)context.Variables["IdToCheck"]);
    }}">
        <mock-response status-code="200" content-type="application/json" />
    </when>
</choose>
</fragment>
'''

var mockResponses = [
  {
    statusCode: 200
    description: 'Ok'
    representations: [
      {
        contentType: 'application/json'
        examples: {
          default: {
            value: '{"status": "ok"}'
          }
        }
      }
    ]
  }
]

resource apim 'Microsoft.ApiManagement/service@2023-05-01-preview' = {
  name: format(uniqueNameFormat, 'api')
  location: location
  tags: tags
  sku: {
    capacity: 1
    name: 'StandardV2'
  }
  properties: {
    publisherEmail: apimEmail
    publisherName: format(uniqueNameFormat, 'apim')
  }

  resource mockTag 'tags' = {
    name: 'mock'
    properties: {
      displayName: 'Mock'
    }
  }
  resource backendTag 'tags' = {
    name: 'backend'
    properties: {
      displayName: 'Backend'
    }
  }

  resource csv100IdValues 'namedValues' = {
    name: 'csv100idvalues'
    properties: {
      displayName: 'csv100idvalues'
      value: ids100csv
    }
  }
  resource csv370IdValues 'namedValues' = {
    name: 'csv370idvalues'
    properties: {
      displayName: 'csv370idvalues'
      value: ids370csv
    }
  }
  resource json100IdValues 'namedValues' = {
    name: 'json100idvalues'
    properties: {
      displayName: 'json100idvalues'
      value: ids100json
    }
  }
  resource json370IdValues 'namedValues' = {
    name: 'json370idvalues'
    properties: {
      displayName: 'json370idvalues'
      value: ids370json
    }
  }
  // A named value has a maximum length of 4096 characters, so we can only fit 372 JSON IDs or 455 CSV IDs in a single named value for 8 character ids, thus no implementation for 1k

  resource inline100Fragment 'policyFragments' = {
    name: 'inline100fragment'
    properties: {
      description: 'Inline 100 value check'
      format: 'rawxml'
      value: format(inlinePolicyFragmentFormat, replace(replace(ids100json, '[', ''), ']', ''))
    }
  }
  resource inline370Fragment 'policyFragments' = {
    name: 'inline370fragment'
    properties: {
      description: 'Inline 370 value check'
      format: 'rawxml'
      value: format(inlinePolicyFragmentFormat, replace(replace(ids370json, '[', ''), ']', ''))
    }
  }
  resource inline1kFragment 'policyFragments' = {
    name: 'inline1kfragment'
    properties: {
      description: 'Inline 1000 value check'
      format: 'rawxml'
      value: format(inlinePolicyFragmentFormat, replace(replace(ids1000json, '[', ''), ']', ''))
    }
  }

  resource api 'apis@2023-05-01-preview' = {
    name: 'latencytest'
    properties: {
      displayName: 'Latency Test'
      path: 'api/latency'
      subscriptionRequired: false
      serviceUrl: 'https://${appSvc.properties.defaultHostName}/'
      protocols: [
        'https'
      ]
    }
    resource apiPolicy 'policies' = {
      name: 'policy'
      properties: {
        format: 'rawxml'
        value: format(inboundPolicyFormat, '<rewrite-uri template="/" copy-unmatched-params="false" />')
      }
    }

    // Normal, no mocking
    resource normalMock 'operations' = {
      name: 'normalmock'
      properties: {
        displayName: 'Normal Mock'
        method: 'GET'
        urlTemplate: 'normal/mock'
        responses: mockResponses
      }
      resource tagRef 'tags' = { name: mockTag.name }
      resource operationPolicy 'policies' = {
        name: 'policy'
        properties: {
          format: 'rawxml'
          value: format(inboundPolicyFormat, '<mock-response status-code="200" content-type="application/json" />')
        }
      }
    }

    resource normalBackend 'operations' = {
      name: 'normalbackend'
      properties: {
        displayName: 'Normal Backend'
        method: 'GET'
        urlTemplate: 'normal/backend'
      }
      resource tagRef 'tags' = { name: backendTag.name }
    }

    // Mock if in ids, otherwise send to backend (Target Scenario)
    resource mockIfFound100CSV 'operations' = {
      name: 'mockiffound100csv'
      properties: {
        displayName: 'Mock if found 100 CSV'
        method: 'GET'
        urlTemplate: 'mockiffound/100/csv'
        responses: mockResponses
      }
      resource operationPolicy 'policies' = {
        name: 'policy'
        properties: {
          format: 'rawxml'
          value: format(mockIfFoundCSVPolicyFormat, '{{${csv100IdValues.name}}}')
        }
      }
    }
    resource mockIfFound370CSV 'operations' = {
      name: 'mockiffound370csv'
      properties: {
        displayName: 'Mock if found 370 CSV'
        method: 'GET'
        urlTemplate: 'mockiffound/370/csv'
        responses: mockResponses
      }
      resource operationPolicy 'policies' = {
        name: 'policy'
        properties: {
          format: 'rawxml'
          value: format(mockIfFoundCSVPolicyFormat, '{{${csv370IdValues.name}}}')
        }
      }
    }
    resource mockIfFound100Json 'operations' = {
      name: 'mockiffound100json'
      properties: {
        displayName: 'Mock if found 100 Json'
        method: 'GET'
        urlTemplate: 'mockiffound/100/json'
        responses: mockResponses
      }
      resource operationPolicy 'policies' = {
        name: 'policy'
        properties: {
          format: 'rawxml'
          value: format(mockIfFoundJsonPolicyFormat, '{{${json100IdValues.name}}}')
        }
      }
    }
    resource mockIfFound370Json 'operations' = {
      name: 'mockiffound370json'
      properties: {
        displayName: 'Mock if found 370 Json'
        method: 'GET'
        urlTemplate: 'mockiffound/370/json'
        responses: mockResponses
      }
      resource operationPolicy 'policies' = {
        name: 'policy'
        properties: {
          format: 'rawxml'
          value: format(mockIfFoundJsonPolicyFormat, '{{${json370IdValues.name}}}')
        }
      }
    }
    resource mockIfFound100Fragment 'operations' = {
      name: 'mockiffound100fragment'
      properties: {
        displayName: 'Mock if found 100 policy fragment'
        method: 'GET'
        urlTemplate: 'mockiffound/100/fragment'
        responses: mockResponses
      }
      resource operationPolicy 'policies' = {
        name: 'policy'
        properties: {
          format: 'rawxml'
          value: format(inboundPolicyFormat, '<include-fragment fragment-id="${inline100Fragment.name}" />')
        }
      }
    }
    resource mockIfFound370Fragment 'operations' = {
      name: 'mockiffound370fragment'
      properties: {
        displayName: 'Mock if found 370 policy fragment'
        method: 'GET'
        urlTemplate: 'mockiffound/370/fragment'
        responses: mockResponses
      }
      resource operationPolicy 'policies' = {
        name: 'policy'
        properties: {
          format: 'rawxml'
          value: format(inboundPolicyFormat, '<include-fragment fragment-id="${inline370Fragment.name}" />')
        }
      }
    }
    resource mockIfFound1kFragment 'operations' = {
      name: 'mockiffound1kfragment'
      properties: {
        displayName: 'Mock if found 1000 policy fragment'
        method: 'GET'
        urlTemplate: 'mockiffound/1000/fragment'
        responses: mockResponses
      }
      resource operationPolicy 'policies' = {
        name: 'policy'
        properties: {
          format: 'rawxml'
          value: format(inboundPolicyFormat, '<include-fragment fragment-id="${inline1kFragment.name}" />')
        }
      }
    }
  }
}

resource appSvcPlan 'Microsoft.Web/serverfarms@2023-12-01' = {
  name: format(uniqueNameFormat, 'asp')
  location: location
  tags: tags
  kind: 'app'
  sku: {
    tier: 'PremiumV3'
    name: 'P1v3'
  }
}

resource appSvc 'Microsoft.Web/sites@2023-12-01' = {
  name: format(uniqueNameFormat, 'site')
  location: location
  tags: tags
  kind: 'app'
  properties: {
    serverFarmId: appSvcPlan.id
    siteConfig: {
      alwaysOn: true
    }
  }
}

module testvm './testvm.bicep' = if (deployTestVm) {
  name: 'testvm'
  params: {
    location: location
    tags: tags
    prefix: prefix
    vmPublicKey: testVmPublicKey
    vmUsername: testVmUsername
    sshAllowedSourceIp: testVmAllowedIp
  }
}
