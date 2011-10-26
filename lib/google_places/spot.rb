require 'open-uri'

module GooglePlaces
  class Spot
    attr_accessor :reference

    def self.list(lat, lng, api_key, options = {})
      radius = options.delete(:radius) || 200
      sensor = options.delete(:sensor) || false
      types  = options.delete(:types)
      name  = options.delete(:name)
      language  = options.delete(:language)
      location = Location.new(lat, lng)
      exclude = options.delete(:exclude) || []

      exclude = [exclude] unless exclude.is_a?(Array)

      options = {
        :location => location.format,
        :radius => radius,
        :sensor => sensor,
        :key => api_key,
        :name => name,
        :language => language
      }

      # Accept Types as a string or array
      if types
        types = (types.is_a?(Array) ? types.join('|') : types)
        options.merge!(:types => types)
      end

      response = Request.spots(options)
      response['results'].map do |result|
        self.new(result, api_key) if (result['types'] & exclude) == []
      end.compact
    end

    def self.find(reference, api_key, options = {})
      sensor = options.delete(:sensor) || false
      language  = options.delete(:language)

      response = Request.spot(
        :reference => reference,
        :sensor => sensor,
        :key => api_key,
        :language => language
      )

      self.new(response['result'], api_key)
    end

    def initialize(json_result_object, api_key)
      set_class_vars(json_result_object)
      @api_key                = api_key
    end
    
    def set_class_vars(json_result_object)
      @reference              = json_result_object['reference']
      @vicinity               = json_result_object['vicinity']
      @lat                    = json_result_object['geometry']['location']['lat']
      @lng                    = json_result_object['geometry']['location']['lng']
      @name                   = json_result_object['name']
      @icon                   = json_result_object['icon']
      @types                  = json_result_object['types']
      @id                     = json_result_object['id']
      @formatted_phone_number = json_result_object['formatted_phone_number']
      @formatted_address      = json_result_object['formatted_address']
      @address_components     = json_result_object['address_components']
      @rating                 = json_result_object['rating']
      @url                    = json_result_object['url']
      @website                = json_result_object['website']
    end
    
    def refresh
      response = Request.spot(
        :reference => @reference,
        :sensor => false,
        :key => @api_key
      )
      
      set_class_vars(response['result'])
      @refreshed = true
    end
    
    def closed?
      web_url = self.url
      if @closed.nil?
        @closed = open(web_url).read.include?('place is permanently closed')
      end
      @closed
    end 
    
    ['lat', 'lng', 'vicinity', 'name', 'icon', 'types', 'id', 'formatted_phone_number', 'formatted_address', 'address_components', 'rating', 'url', 'website'].each do |local_method|
      class_eval %Q&
        def #{local_method}
          if @#{local_method}.nil? and !@refreshed
            refresh
          end
          @#{local_method}
        end
      &
    end
    
    def has_details?
      @address_components || @formatted_address || @formatted_phone_number
    end

    def street_number
      parsed_address(:street_number)
    end

    def route
      parsed_address(:route)
    end

    def address
      [street_number, route].join(' ').strip
    end

    def city
      parsed_address(:locality)
    end
    
    def state
      parsed_address(:administrative_area_level_1)
    end
    
    def country
      parsed_address(:country)
    end

    def postal_code
      parsed_address(:postal_code)
    end

    def zip5
      postal_code.split('-').first || ''
    end

    def parsed_address(field,subfield='short_name')
      # invert the goog array into a Hash of :type => {component}
      @parsed_address ||= Hash[*[
        address_components.map do |c| 
          c.delete('types').map {|t| [t.intern, c] }
        end
      ].flatten]
      @parsed_address[field] ? @parsed_address[field][subfield] : ''
    end
    
  end
end
