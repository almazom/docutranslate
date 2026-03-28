Feature: Text upload flow
  Scenario: Upload a text file and retrieve the generated output
    Given the DocuTranslate landing page is open
    When I create a new translation task
    And I configure text workflow with skip translation enabled
    And I upload the sample text document
    And I start the active task
    Then the active task finishes with downloadable results
    When I download the translated text result
    Then the downloaded text matches the sample document
    When I open the translated preview
    Then the translated preview includes the sample document text
