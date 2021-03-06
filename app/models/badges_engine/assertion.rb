require 'uri'
require 'json'
require 'chunky_png'

module BadgesEngine
  class Assertion < ActiveRecord::Base

    include BadgesEngine::Engine.routes.url_helpers

    belongs_to :badge

    validates_presence_of :badge_id
    validates_presence_of :user_id

    validates_associated :badge

    before_validation(:on=>:create) do
      self.token = SecureRandom.urlsafe_base64(16)
    end

    class <<self
      def associate_user_class(user_class)
        belongs_to :user, :class_name=>user_class.to_s, :foreign_key=>'user_id'
      end
    end

    def recipient
      'sha256$' + Digest::SHA256.hexdigest(self.user.try(:email) + salt)
    end

    def salt
      BadgesEngine::Configuration.salt
    end

    def baking_callback_url
      origin_uri = URI.parse(BadgesEngine::Configuration.issuer.origin)
      secret_assertion_url(:id=>self.id, :token=>self.token, :host=>origin_uri.host)
    end

    def bake
      image = ChunkyPNG::Image.from_blob(open(badge.image).read)
      image.metadata['openbadges'] = baking_callback_url
      image.to_blob
    end

    def as_json(options={})
      super(only: [:evidence, :expires, :issued_on], methods: [:recipient, :salt],
            include: { badge: { only: [:version, :name, :image, :description, :criteria], methods: :issuer} })
    end

  end
end
