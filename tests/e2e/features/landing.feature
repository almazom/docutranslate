Feature: Landing page
  Scenario: Primary controls are visible on load
    Given the DocuTranslate landing page is open
    Then the app title is shown
    And the workflow selector is available
    When I create a new translation task
    Then an empty task card is ready for upload
