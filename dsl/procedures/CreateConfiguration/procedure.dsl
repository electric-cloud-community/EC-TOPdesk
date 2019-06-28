
// === configuration starts ===
// This part is auto-generated and will be regenerated upon subsequent updates
procedure 'CreateConfiguration', description: 'Creates a plugin configuration', {

    step 'createConfiguration',
        command: new File(pluginDir, "dsl/procedures/CreateConfiguration/steps/createConfiguration.pl").text,
        errorHandling: 'abortProcedure',
        exclusiveMode: 'none',
        postProcessor: 'postp',
        releaseMode: 'none',
        shell: 'ec-perl',
        timeLimitUnits: 'minutes'

    property 'ec_checkConnection', value: ''
// === configuration ends, checksum: 8e292d191415a8f02e2350128b9946c2 ===
}
