@real-translation
Feature: Real DeepSeek translation through the web interface
  Scenario Outline: Translate the <fixtureKey> sample with DeepSeek using the <workflow> workflow
    Given translation API credentials are configured for browser E2E
    And the DocuTranslate landing page is open
    When I create a new translation task
    And I configure real translation mode for the "<workflow>" workflow
    And I upload the "<fixtureKey>" sample document
    And I start the active task
    Then the active task finishes with downloadable results
    And the "<downloadType>" download is available for the active task
    When I open the translated preview
    Then the translated preview for the "<fixtureKey>" sample is different from the original text

    Examples:
      | workflow | fixtureKey | downloadType |
      | txt      | txt        | txt          |
      | docx     | docx       | docx         |
      | docx     | docx_rich  | docx         |
      | xlsx     | xlsx       | xlsx         |
      | xlsx     | xlsx_rich  | xlsx         |
      | pptx     | pptx       | pptx         |
      | pptx     | pptx_rich  | pptx         |
