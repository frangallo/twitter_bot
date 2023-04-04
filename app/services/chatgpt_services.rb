class ChatgptService
  include HTTParty

  attr_reader :api_url, :options, :model, :message

  def initialize(prompt. model = 'gpt-4')
    api_key = Rails.application.credentials.openai[:api_key]
    @options = {
      headers: {
        'Content-Type' => 'application/json',
        'Authorization' => "Bearer #{api_key}"
      }
    }
    @api_url = 'https://api.openai.com/v1/chat/completions'
    @model = model
    @message = prompt

  end

  def call
    body = {
      model:,
      messages: [{ role: 'user', content: message}],
      temperature: 0.7,
      max_tokens: 256,
      top_p: 1,
      frequency_penalty: 0,
      presence_penalty: 0
    }
    response = HTTParty.post(api_url, body: body.to_json, headers: options[:headers], timeout: 20)
    raise response['error']['message'] unless response.code == 200

    response['choices'][0]['message']['content']
  end

  class << self
    def call(prompt, model = 'gpt-4')
      new(prompt, model).call
    end
  end
end
