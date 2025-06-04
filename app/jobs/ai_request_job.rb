class AiRequestJob < ApplicationJob
  queue_as :default

  def perform(ai_request_params, api_key)
    connection = Faraday.new(url: 'https://api.openai.com')
  
    response = connection.post do |req|
      req.url "/v1/chat/completions"
      req.headers['Content-Type'] = 'application/json'
      req.headers['Authorization'] = "Bearer #{api_key}"
      req.body = {
        model: "gpt-3.5-turbo",
        messages: [
          { role: "user", content: ai_request_params[:prompt] }
        ],
        temperature: 0.5,
        max_tokens: 250
      }.to_json
    end
  
    begin
      json_response = JSON.parse(response.body)
      Rails.logger.info "OpenAI response: #{json_response.inspect}"
      generated_idea = json_response.dig("choices", 0, "message", "content") || "No idea generated."
    rescue JSON::ParserError => e
      Rails.logger.error("JSON Parse Error: #{e.message}")
      generated_idea = "Error parsing OpenAI response."
    end
  
    uuid = ai_request_params[:uuid]
  
    Turbo::StreamsChannel.broadcast_update_to(
      "channel_#{uuid}",
      target: 'ai_output',
      partial: 'ai/output',
      locals: { generated_idea: }
    )
  end  
end