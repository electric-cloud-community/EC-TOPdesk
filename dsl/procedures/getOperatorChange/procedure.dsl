// This procedure.dsl was generated automatically
// === procedure_autogen starts ===
procedure 'getOperatorChange', description: 'Get an operator change record', {

    step 'getOperatorChange', {
        description = ''
        command = new File(pluginDir, "dsl/procedures/getOperatorChange/steps/getOperatorChange.pl").text
        shell = 'ec-perl'

        }

    formalOutputParameter 'change',
        description: 'JSON representation of the operator change'
// === procedure_autogen ends, checksum: 909f6fab1d902241ae6874d46c1b5633 ===
// procedure properties declaration can be placed in here, like
// property 'property name', value: "value"
}