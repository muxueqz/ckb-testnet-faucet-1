# frozen_string_literal: true

class SendCapacityService
  def initialize(ckb_wallet)
    @ckb_wallet = ckb_wallet
  end

  def call
    ClaimEvent.transaction do
      first_pending_event = ClaimEvent.order(:id).pending.first
      return if first_pending_event.blank?

      first_pending_event.lock!
      if first_pending_event.tx_hash.present?
        tx = ckb_wallet.get_transaction(first_pending_event.tx_hash)

        if tx.present?
          handle_state_change(first_pending_event, tx)
        else
          handle_send_capacity(first_pending_event)
        end
      else
        handle_send_capacity(first_pending_event)
      end
    end
  end

  private
    attr_reader :ckb_wallet

    def handle_state_change(first_pending_event, tx)
      return if tx.tx_status.status == "pending"

      if tx.tx_status.status == "committed"
        first_pending_event.processed!
        first_pending_event.update!(tx_status: tx.tx_status.status)
        Account.official_account.decrement!(:balance, first_pending_event.capacity)
      else
        first_pending_event.update!(tx_status: tx.tx_status.status)
      end
    end

    def handle_send_capacity(first_pending_event)
      tx = ckb_wallet.generate_tx(first_pending_event.address_hash, first_pending_event.capacity)
      tx.witnesses = tx.witnesses.map do |witness|
        case witness
        when CKB::Types::Witness
          CKB::Serializers::WitnessArgsSerializer.from(witness).serialize
        else
          witness
        end
      end
      min_tx_fee = tx.fee(1000) + 100
      tx_hash = ckb_wallet.send_capacity(first_pending_event.address_hash, first_pending_event.capacity, fee: min_tx_fee, outputs_validator: "passthrough")
      first_pending_event.update!(tx_hash: tx_hash, tx_status: "pending", fee: min_tx_fee)
    rescue CKB::RPCError => e
      puts e
    end
end
