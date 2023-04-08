require 'rest-client'
require 'httparty'

module OpenaiServices
  class ChatgptService
    attr_reader :api_url, :options, :model, :prompt

    def initialize(prompt, model = 'gpt-4')
      api_key = Rails.application.credentials[:openai][:api_key]
      @options = {
        headers: {
          'Content-Type' => 'application/json',
          'Authorization' => "Bearer #{api_key}"
        }
      }
      @api_url = 'https://api.openai.com/v1/chat/completions'
      @model = model
      @prompt = prompt

    end

    def call
      body = {
        model: model,
        messages: [{ role: 'user', content: prompt}],
        temperature: 0.7,
        max_tokens: 500,
        top_p: 1,
        frequency_penalty: 0,
        presence_penalty: 0
      }
      response = HTTParty.post(api_url, body: body.to_json, headers: options[:headers], timeout: 60)
      raise response['error']['message'] unless response.code == 200

      response['choices'][0]['message']['content']
    end

    class << self
      def call(prompt, model = 'gpt-4')
        new(prompt, model).call
      end
    end
  end

  class DalleService
    attr_reader :api_url, :options, :prompt

    def initialize(prompt)
      api_key = Rails.application.credentials.openai[:api_key]
      @options = {
        headers: {
          'Content-Type' => 'application/json',
          'Authorization' => "Bearer #{api_key}"
        }
      }
      @api_url = 'https://api.openai.com/v1/images/generations'
      @prompt = prompt

    end

    def call
      body = {
        prompt: prompt,
        n: 1,
        size: "1024x1024"
      }
      response = HTTParty.post(api_url, body: body.to_json, headers: options[:headers], timeout: 60)
      raise response['error']['message'] unless response.code == 200
      image_url = response['data'][0]['url']

      puts 'Downloading generated image...'
      image_data = RestClient.get(image_url).body

      puts 'Image data encoding:'
      puts image_data.encoding

      image_data
    rescue StandardError => e
      Rails.logger.error "Error generating image: #{e.message}"
      File.read('path/to/placeholder/image.png')
    end

    class << self
      def call(prompt)
        new(prompt).call
      end
    end
  end
end
