// This procedure.dsl was generated automatically
// === procedure_autogen starts ===
// === procedure_autogen template ===
procedure '{{procedure.name}}', description: '{{procedure.description}}', {
{% for step in procedure.steps %}
    step '{{ step.name }}', {
        description = '{{ step.description }}'
        command = new File(pluginDir, "dsl/procedures/{{ procedure.procedureFolderName }}/steps/{{ step.stepFileName() }}").text
        shell = '{{ step.shell }}'
        {% for paramKey in step.additionalParameters.keySet() %}
        {% if (paramKey) %}{{paramKey}} = '{{ step.additionalParameters.get(paramKey) }}'{% endif %}
        {% endfor %}
    }
{% endfor %}
{% for outputParameter in procedure.outputParameters %}
    formalOutputParameter '{{ outputParameter.name }}',
        description: '{{ outputParameter.description }}'
{% endfor %}
// === procedure_autogen template ends===
// === procedure_autogen ends ===
// procedure properties declaration can be placed in here, like
// property 'property name', value: "value"
}
