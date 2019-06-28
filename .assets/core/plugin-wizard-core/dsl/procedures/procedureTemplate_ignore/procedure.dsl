// This procedure.dsl was generated automatically
// === procedure_autogen starts ===
// === procedure_autogen template ===
procedure '{{procedure.name}}', description: '{{procedure.description}}', {
{% for step in procedure.steps %}
    step '{{ step.name }}', {
        description = '{{ step.description }}'
        {% if step.shell %}command = new File(pluginDir, "dsl/procedures/{{ procedure.procedureFolderName }}/steps/{{ step.stepFileName() }}").text{% endif %}
        {% if step.shell %}shell = '{{ step.shell }}'{% endif %}
        {% for paramKey in step.additionalParameters.keySet() %}
        {% if (paramKey) %}{{paramKey}} = '{{ step.additionalParameters.get(paramKey) }}'{% endif %}
        {% endfor %}

        {%- if step.actualParameters %}
        actualParameter = [
            {%- for key, value in step.actualParameters %}
            '{{key}}' : '{{value}}',
            {% endfor -%}
        ]
        {% endif -%}
    }

{% endfor %}
{% for outputParameter in procedure.outputParameters %}
    formalOutputParameter '{{ outputParameter.name }}',
        description: '{{ outputParameter.description }}'
{% endfor %}
// === procedure_autogen template ends===
// === procedure_autogen ends ===
// Do not update the code above the line
// procedure properties declaration can be placed in here, like
// property 'property name', value: "value"
}
