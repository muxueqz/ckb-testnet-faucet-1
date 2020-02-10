# frozen_string_literal: true

require "test_helper"

class SendCapacityServiceTest < ActiveSupport::TestCase
  test "should fill tx_hash and tx_status to first pending event" do
    create_list(:claim_event, 15)
    create_list(:claim_event, 15, status:"processed")
    first_pending_event = ClaimEvent.order(:id).pending.first
    tx_hash = "0x1deb37a41c037919d8b0bbce6e7ac19fb00b7e12f0cacff369acd416369e72d9"
    ckb_wallet = mock
    ckb_wallet.expects(:send_capacity).with(first_pending_event.address_hash, ClaimEvent::DEFAULT_CLAIM_CAPACITY).returns(tx_hash)

    assert_changes -> {first_pending_event.reload.tx_hash }, from: nil, to: tx_hash do
      SendCapacityService.new(ckb_wallet).call
    end
  end
end