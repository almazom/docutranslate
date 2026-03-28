Feature: Multi-format browser download coverage
  Scenario Outline: Browser flow stays healthy for <workflow> uploads
    Given the DocuTranslate landing page is open
    When I create a new translation task
    And I configure the "<workflow>" workflow for skip translation
    And I upload the "<fixtureKey>" sample document
    And I start the active task
    Then the active task finishes with downloadable results
    And the "<downloadType>" download is available for the active task
    When I open the translated preview
    Then the translated preview contains text from the "<fixtureKey>" sample document

    Examples:
      | workflow | fixtureKey | downloadType |
      | txt      | txt        | txt          |
      | docx     | docx       | docx         |
      | xlsx     | xlsx       | xlsx         |
      | pptx     | pptx       | pptx         |
