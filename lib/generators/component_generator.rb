class ComponentGenerator < Rails::Generators::Base
  argument :component_name, required: true, desc: "Component name, e.g: button"
  argument :component_level, desc: "Atomic Design level (atom, molecule or organism"

  def create_view_file
    create_file "#{component_path}/_#{component_name}.html.#{template_engine}" do
      "<div class='#{component_name}'></div>"
    end
  end

  def create_css_file
    create_file "#{component_path}/#{component_name}.css"
  end

  def create_js_file
    create_file "#{component_path}/#{component_name}.js" do
      # require component's CSS inside JS automatically
      "import \"./#{component_name}.css\";\n.#{component_name} {}"
    end
  end

  protected

  def component_path
    if component_level
      "frontend/components/#{component_level}s/#{component_name}"
    else
      "frontend/components/organisms/#{component_name}"
    end
  end

  def template_engine
    Rails.application.config.generators.options[:rails][:template_engine]
  end
end