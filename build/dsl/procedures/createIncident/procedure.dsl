procedure 'createIncident', description: 'Create a new incident', { // [PROCEDURE]
    // [REST Plugin Wizard step]

    step 'createIncident',
        command: """
\$[/myProject/scripts/preamble]
use EC::TOPdesk::Plugin;
EC::TOPdesk::Plugin->new->run_step('createIncident');
""",
        errorHandling: 'failProcedure',
        exclusiveMode: 'none',
        releaseMode: 'none',
        shell: 'ec-perl',
        timeLimitUnits: 'minutes'
    
    // [REST Plugin Wizard step ends]
    // [Output Parameters Begin]

    // [Output Parameters End]
}
