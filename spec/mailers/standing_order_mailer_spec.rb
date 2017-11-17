require 'spec_helper'

describe StandingOrderMailer do
  include ActionView::Helpers::SanitizeHelper

  let!(:mail_method) { create(:mail_method, preferred_mails_from: 'spree@example.com') }

  describe "order placement" do
    let(:standing_order) { create(:standing_order, with_items: true) }
    let(:proxy_order) { create(:proxy_order, standing_order: standing_order) }
    let!(:order) { proxy_order.initialise_order! }

    context "when changes have been made to the order" do
      let(:changes) { {} }

      before do
        changes[order.line_items.first.id] = 2
        expect do
          StandingOrderMailer.placement_email(order, changes).deliver
        end.to change{ StandingOrderMailer.deliveries.count }.by(1)
      end

      it "sends the email, which notifies the customer of changes made" do
        body = StandingOrderMailer.deliveries.last.body.encoded
        expect(body).to include "This order was automatically created for you."
        expect(body).to include "Unfortunately, not all products that you requested were available."
        expect(body).to include "href=\"#{spree.order_url(order)}\""
      end
    end

    context "and changes have not been made to the order" do
      before do
        expect do
          StandingOrderMailer.placement_email(order, {}).deliver
        end.to change{ StandingOrderMailer.deliveries.count }.by(1)
      end

      it "sends the email" do
        body = StandingOrderMailer.deliveries.last.body.encoded
        expect(body).to include "This order was automatically created for you."
        expect(body).to_not include "Unfortunately, not all products that you requested were available."
        expect(body).to include "href=\"#{spree.order_url(order)}\""
      end
    end
  end

  describe "order confirmation" do
    let(:standing_order) { create(:standing_order, with_items: true) }
    let(:proxy_order) { create(:proxy_order, standing_order: standing_order) }
    let!(:order) { proxy_order.initialise_order! }

    before do
      expect do
        StandingOrderMailer.confirmation_email(order).deliver
      end.to change{ StandingOrderMailer.deliveries.count }.by(1)
    end

    it "sends the email" do
      body = StandingOrderMailer.deliveries.last.body.encoded
      expect(body).to include "This order was automatically placed for you"
      expect(body).to include "href=\"#{spree.order_url(order)}\""
    end
  end

  describe "empty order notification" do
    let(:standing_order) { create(:standing_order, with_items: true) }
    let(:proxy_order) { create(:proxy_order, standing_order: standing_order) }
    let!(:order) { proxy_order.initialise_order! }

    before do
      expect do
        StandingOrderMailer.empty_email(order, {}).deliver
      end.to change{ StandingOrderMailer.deliveries.count }.by(1)
    end

    it "sends the email" do
      body = StandingOrderMailer.deliveries.last.body.encoded
      expect(body).to include "We tried to place a new order with"
      expect(body).to include "Unfortunately, none of products that you ordered were available"
    end
  end

  describe "failed payment notification" do
    let(:standing_order) { create(:standing_order, with_items: true) }
    let(:proxy_order) { create(:proxy_order, standing_order: standing_order) }
    let!(:order) { proxy_order.initialise_order! }

    before do
      order.errors.add(:base, "This is a payment failure error")

      expect do
        StandingOrderMailer.failed_payment_email(order).deliver
      end.to change{ StandingOrderMailer.deliveries.count }.by(1)
    end

    it "sends the email" do
      body = strip_tags(StandingOrderMailer.deliveries.last.body.encoded)
      expect(body).to include I18n.t("email_so_failed_payment_intro_html")
      explainer = I18n.t("email_so_failed_payment_explainer_html", distributor: standing_order.shop.name)
      expect(body).to include strip_tags(explainer)
      details = I18n.t("email_so_failed_payment_details_html", distributor: standing_order.shop.name)
      expect(body).to include strip_tags(details)
      expect(body).to include "This is a payment failure error"
    end
  end
end