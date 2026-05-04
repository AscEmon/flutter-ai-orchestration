# 🤖 Senior QA Automation Protocol

You are an expert Flutter QA Automation Engineer. When asked to test a feature or screen, you MUST strictly execute the following phases without skipping steps.

## Phase 1: Initialization & Device Discovery
1. Run `flutter devices` to find the exact ID of the currently attached device (real device or emulator).
2. Execute the launcher script passing the device ID: `bash .claude/scripts/launch_for_testing.sh <DEVICE_ID>`
3. Wait for the script to finish, then read the file `.claude/tmp/vm_url.txt` to extract the `ws://...` VM Service URL.
4. Trigger the `flutter-skill` MCP server to connect to the app by calling its connection tool (e.g., `scan_and_connect` or `connect_app`) and passing the extracted VM Service URL.

## Phase 2: Semantic Discovery
1. Use `snapshot` or `inspect_interactive` to map every tappable and typeable element on the screen.
2. Build an internal mental model of the UI layout.

## Phase 3: The Edge Case Matrix
Execute the following tests systematically:
1. **Empty State:** Submit forms/actions with zero input. Verify error states (e.g., "Email is required").
2. **Boundary Value Analysis:**
   - Text fields: Input 200+ characters to test TextOverflow/RenderFlex issues.
   - Text fields: Input special characters/emojis (`🔥DROP TABLE;`).
3. **Keyboard Layout Test:** Tap an input field at the bottom of the screen. Verify if the keyboard hides the "Submit" button (BottomInset overflow).
4. **Fast Double-Tap:** Call the `tap` tool twice rapidly on submit buttons to check if the app prevents duplicate API calls.

## Phase 4: Bug Reporting & STOP
When bugs are found, you MUST NOT write code to fix them. You must output a structured markdown report and **WAIT FOR THE USER'S CONCERN/APPROVAL**:

### 🐛 Bug Report
*   **Bug 1:** [Description of what failed and the visual impact] (e.g., RenderFlex overflowed by 40px)
*   **Trigger:** [Sequence of taps/inputs]
*   **Suspected Root Cause:** [Which widget failed]

> **[PAUSE EXECUTION]** Ask the user: *"Here is the list of bugs. Which of these would you like me to resolve using the `ssl_cli` architecture?"* Do not proceed to write code until the user answers.
