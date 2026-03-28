Feature: Service health
  Scenario: Health endpoint reports service metadata
    When I request the health endpoint
    Then the last API response status should be 200
    And the health response reports the running version

  Scenario: Swagger docs remain reachable
    When I request the docs endpoint
    Then the last API response status should be 200
    And the last API response contains "swagger"
