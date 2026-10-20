class SendWebhookEventJob < ApplicationJob
  queue_as :default

  def perform(conversation_id, webhook_url, event: 'conversation_updated')
    conversation = Conversation.find_by(id: conversation_id)
    return unless conversation.present?

    payload = {
      event: event,
      id: conversation.id,
      account_id: conversation.account_id,
      inbox_id: conversation.inbox_id,
      status: conversation.status
    }

    response = RestClient::Request.execute(
      method: :post,
      url: webhook_url,
      payload: payload.to_json,
      headers: { content_type: :json, accept: :json },
      timeout: 10
    )

    if response.code.between?(200, 299)
      Inbox.update_counters(conversation.inbox_id, webhook_delivery_count: 1)
      Rails.logger.info("Webhook delivered for conversation #{conversation_id}: #{response.code}")
    end
  rescue StandardError => e
    Rails.logger.warn("Webhook delivery failed for conversation #{conversation_id}: #{e.class}: #{e.message}")
    raise e
  end
end
