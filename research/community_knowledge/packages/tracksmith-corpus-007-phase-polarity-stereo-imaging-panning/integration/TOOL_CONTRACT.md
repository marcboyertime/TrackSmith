# Tool Contract

Suggested read-only capability:

`search_phase_stereo_panning_knowledge`

Input:

- query
- source type and channel format
- current Logic version
- current capture scope
- stereo/mono complaint
- related-signal context
- desired position/width/depth
- current routing and pan mode when user-reported or observed
- maximum results

Output:

- package ID/version
- interpreted question
- selected candidate record IDs
- compact practitioner/documentary patterns
- one relevant disagreement
- myths/anti-patterns
- source IDs and evidence classes
- version limitations
- suggested clarification
- suggested reversible listening experiment

The tool is read-only. It must never perform or authorize a Logic, Audio Unit, file, or project mutation.
