class SendWebhookEventJob < ApplicationJob
  queue_as :default

  # Anti-pattern 1: Passing full ActiveRecord instance instead of ID
  def perform(conversation, webhook_url)
    return unless conversation.present?

    payload = {
      id: conversation.id,
      inbox_id: conversation.inbox_id,
      status: conversation.status
    }

    # Anti-pattern 2: Non-atomic counter update (race condition)
    conversation.inbox.update(webhook_delivery_count: conversation.inbox.webhook_delivery_count + 1)

    response = RestClient::Request.execute(
      method: :post,
      url: webhook_url,
      payload: payload.to_json,
      headers: { content_type: :json, accept: :json },
      timeout: 10
    )

    Rails.logger.info("Webhook delivered: #{response.code}")
  rescue StandardError => e
    # Anti-pattern 3: Swallowing exception (breaks Sidekiq retry mechanism)
    nil
  end
end
