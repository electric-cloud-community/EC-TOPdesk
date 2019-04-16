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
// === procedure_autogen ends, checksum: a58d7fc15b691b630bd6dfef84e8770f ===
// procedure properties declaration can be placed in here, like
// property 'property name', value: "value"
}