// This procedure.dsl was generated automatically
// === procedure_autogen starts ===
procedure 'createOperatorChange', description: 'Create a new change for an operator', {

    step 'createOperatorChange', {
        description = ''
        command = new File(pluginDir, "dsl/procedures/createOperatorChange/steps/createOperatorChange.pl").text
        shell = 'ec-perl'

    }

    formalOutputParameter 'change',
        description: 'JSON representation of the created operator change'

    formalOutputParameter 'changeId',
        description: 'Change ID of the created operator change'
// === procedure_autogen ends, checksum: 5c50560858b778a8f7c01eac9f455812 ===
// procedure properties declaration can be placed in here, like
// property 'property name', value: "value"
}