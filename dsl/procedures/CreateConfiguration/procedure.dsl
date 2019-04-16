import java.io.File

// This file was automatically generated. It will not be regenerated upon subsequent updates.
procedure 'CreateConfiguration', description: 'Creates a plugin configuration', {



    step 'checkConnection',
        command: new File(pluginDir, "dsl/procedures/CreateConfiguration/steps/checkConnection.pl").text,
        errorHandling: 'abortProcedure',
        shell: 'ec-perl',
        resourceName: ''


    step 'createConfiguration',
        command: new File(pluginDir, "dsl/procedures/CreateConfiguration/steps/createConfiguration.pl").text,
        errorHandling: 'abortProcedure',
        exclusiveMode: 'none',
        postProcessor: 'postp',
        releaseMode: 'none',
        shell: 'ec-perl',
        timeLimitUnits: 'minutes'
}
