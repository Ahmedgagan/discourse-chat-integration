require 'rails_helper'

describe 'Mattermost Command Controller', type: :request do
  let(:category) { Fabricate(:category) }
  let(:tag) { Fabricate(:tag) }
  let(:tag2) { Fabricate(:tag) }
  let!(:chan1){DiscourseChat::Channel.create!(provider:'mattermost', data:{identifier: '#welcome'})}

  describe 'with plugin disabled' do
    it 'should return a 404' do
      post '/chat-integration/mattermost/command.json'
      expect(response.status).to eq(404)
    end
  end

  describe 'with plugin enabled and provider disabled' do
    before do
      SiteSetting.chat_integration_enabled = true
      SiteSetting.chat_integration_mattermost_enabled = false
    end

    it 'should return a 404' do
      post '/chat-integration/mattermost/command.json'
      expect(response.status).to eq(404)
    end
  end
  
  describe 'slash commands endpoint' do
    before do
      SiteSetting.chat_integration_enabled = true
      SiteSetting.chat_integration_mattermost_webhook_url = "https://hooks.mattermost.com/services/abcde"
      SiteSetting.chat_integration_mattermost_enabled = true
    end

    describe 'when forum is private' do
      it 'should not redirect to login page' do
        SiteSetting.login_required = true
        token = 'sometoken'
        SiteSetting.chat_integration_mattermost_incoming_webhook_token = token

        post '/chat-integration/mattermost/command.json', text: 'help', token: token

        expect(response.status).to eq(200)
      end
    end

    describe 'when the token is invalid' do
      it 'should raise the right error' do
        expect { post '/chat-integration/mattermost/command.json', text: 'help' }
          .to raise_error(ActionController::ParameterMissing)
      end
    end

    describe 'when incoming webhook token has not been set' do
      it 'should raise the right error' do
        post '/chat-integration/mattermost/command.json', text: 'help', token: 'some token'

        expect(response.status).to eq(403)
      end
    end

    describe 'when token is valid' do
      let(:token) { "Secret Sauce" }

      # No need to test every single command here, that's tested
      # by helper_spec upstream

      before do
        SiteSetting.chat_integration_mattermost_incoming_webhook_token = token
      end

      describe 'add new rule' do
        
        it 'should add a new rule correctly' do
          post "/chat-integration/mattermost/command.json",
            text: "watch #{category.slug}",
            channel_name: 'welcome',
            token: token

          json = JSON.parse(response.body)

          expect(json["text"]).to eq(I18n.t("chat_integration.provider.mattermost.create.created"))

          rule = DiscourseChat::Rule.all.first
          expect(rule.channel).to eq(chan1)
          expect(rule.filter).to eq('watch')
          expect(rule.category_id).to eq(category.id)
          expect(rule.tags).to eq(nil)
        end

        context 'from an unknown channel' do
          it 'creates the channel' do
            post "/chat-integration/mattermost/command.json",
            text: "watch #{category.slug}",
            channel_name: 'general',
            token: token

            json = JSON.parse(response.body)

            expect(json["text"]).to eq(I18n.t("chat_integration.provider.mattermost.create.created"))

            chan = DiscourseChat::Channel.with_provider('mattermost').with_data_value('identifier','#general').first
            expect(chan.provider).to eq('mattermost')

            rule = chan.rules.first
            expect(rule.filter).to eq('watch')
            expect(rule.category_id).to eq(category.id)
            expect(rule.tags).to eq(nil)
          end
        end
      end

    end
  end
end
