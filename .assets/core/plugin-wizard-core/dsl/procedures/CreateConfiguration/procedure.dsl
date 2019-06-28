import java.io.File

// === configuration template ===
// This part is auto-generated and will be regenerated upon subsequent updates
procedure 'CreateConfiguration', description: 'Creates a plugin configuration', {
{% if (shell == "ec-groovy" and checkConnection and false)  %}
    //First, let's download third-party dependencies
    step 'setup',
        command: new File(pluginDir, "dsl/properties/scripts/downloadGrapeDependencies.pl").text,
        shell: 'ec-perl'
        errorHandling: 'failProcedure'
{% endif %}

{% if (checkConnection) %}
    step 'checkConnection',
        command: new File(pluginDir, "dsl/procedures/CreateConfiguration/steps/checkConnection{{ extension }}").text,
        errorHandling: 'abortProcedure',
        shell: '{{shell}}',
        condition: '$[/javascript myJob.checkConnection == "true"]'
{% endif %}


{% if (checkConnectionGeneric) %}
    step 'checkConnectionGeneric',
        command: new File(pluginDir, "dsl/procedures/CreateConfiguration/steps/checkConnectionGeneric{{ checkConnectionGenericExtension }}").text,
        errorHandling: 'abortProcedure',
        shell: '{{checkConnectionGenericShell}}',
        condition: '$[/javascript myJob.checkConnection == "true"]'
{% endif %}

    step 'createConfiguration',
        command: new File(pluginDir, "dsl/procedures/CreateConfiguration/steps/createConfiguration.pl").text,
        errorHandling: 'abortProcedure',
        exclusiveMode: 'none',
        postProcessor: 'postp',
        releaseMode: 'none',
        shell: 'ec-perl',
        timeLimitUnits: 'minutes'

    property 'ec_checkConnection', value: '{{ checkConnectionMetadata }}'
// === configuration template ends ===
// === configuration ends ===
// Place your code below
}
