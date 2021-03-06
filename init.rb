#
# vendor/plugins/redmine_etherpad/init.rb
#

require 'redmine'
require 'uri'
require 'net/http'
require 'json'

Redmine::Plugin.register :redmine_etherpad do
  name 'Redmine Etherpad plugin'
  author 'Charlie DeTar'
  description 'Embed etherpad-lite pads in redmine wikis.'
  version '0.0.1'
  url 'https://github.com/yourcelf/redmine_etherpad'
  author_url 'https://github.com/yourcelf'

  Redmine::WikiFormatting::Macros.register do
    desc "Embed etherpad"
    macro :etherpad do |obj, args|
      conf = Redmine::Configuration['etherpad']
      unless conf and conf['host'] 
        raise "Please define etherpad parameters in configuration.yml."
      end

      # Defaults from configuration.
      controls = {
        'showControls' => conf.fetch('showControls', true),
        'showChat' => conf.fetch('showChat', true),
        'showLineNumbers' => conf.fetch('showLineNumbers', false),
        'useMonospaceFont' => conf.fetch('useMonospaceFont', false),
        'noColors' => conf.fetch('noColors', false),
        'width' => conf.fetch('width', '640px'),
        'height' => conf.fetch('height', '480px'),
      }

      # Override defaults with given arguments.
      padname, *params = args
      for param in params
        key, val = param.strip().split("=")
        unless controls.has_key?(key)
          raise "#{key} not a recognized parameter."
        else
          controls[key] = val
        end
      end

      # compute pad name
      if padname.to_s.strip.length == 0 
        if obj.is_a?(Issue)
          padname = "issue#{obj.id}"
        elsif obj.is_a?(WikiContent) || obj.is_a?(WikiContent::Version)
          padname = "wiki#{obj.id}"
        end
      end
      
      addContext = conf.fetch('addContext', true)
      addProject = conf.fetch('addProject', true)

      if addProject
        padname = "#{@project.identifier}-#{padname}"
      end

      if addContext
        context = conf.fetch('context', 'redmine')
        padname = "#{context}-#{padname}"
      end


      # Set current user name.
      #if User.current
      canEditProject = User.current.allowed_to?({:controller => 'projects', :action => "edit"}, @project)
      
      if User.current and canEditProject
        controls['userName'] = User.current.name
      elsif conf.fetch('loginRequired', true) and not canEditProject
        apikey = conf.fetch('apikey', '')
        if apikey.length == 0
          return "TODO: embed read-only."          
        else
          resultHttp = Net::HTTP.get(URI.parse("#{conf['host']}//api/1/getHTML?padID=#{padname}&apikey=#{apikey}"))
          html = JSON.parse(resultHttp)['data']['html']
          return content_tag('div', html, {'class'=>'etherpad'}, false)
        end
      end

      width = controls.delete('width')
      height = controls.delete('height')

      def hash_to_querystring(hash)
        hash.keys.inject('') do |query_string, key|
          query_string << '&' unless key == hash.keys.first
          query_string << "#{URI.encode(key.to_s)}=#{URI.encode(hash[key].to_s)}"
        end
      end
      
      return tag('iframe', {:src=>"#{conf['host']}/p/#{URI.encode(padname)}?#{hash_to_querystring(controls)}", :width=>"#{width}", :height=>"#{height}"}, false, false)
    end
  end
end
