import java.io.File

// This file was automatically generated. It will not be regenerated upon subsequent updates.
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
        command: new File(pluginDir, "dsl/procedures/CreateConfiguration/steps/checkConnection.{{ extension }}").text,
        errorHandling: 'abortProcedure',
        shell: '{{shell}}',
        resourceName: '{{resourceName}}'
{% endif %}

    step 'createConfiguration',
        command: new File(pluginDir, "dsl/procedures/CreateConfiguration/steps/createConfiguration.pl").text,
        errorHandling: 'abortProcedure',
        exclusiveMode: 'none',
        postProcessor: 'postp',
        releaseMode: 'none',
        shell: 'ec-perl',
        timeLimitUnits: 'minutes'
}
