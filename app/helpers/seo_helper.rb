module SeoHelper
  DEFAULT_TITLE = "Mezzanine — Coworking in Matosinhos".freeze
  DEFAULT_DESCRIPTION = "Mezzanine is a coworking space in Matosinhos near Porto. Daily passes, monthly desks, and a meeting room with sea-side access from 8:00–20:00.".freeze
  SITE_NAME = "Mezzanine cowork".freeze

  def seo_title
    content_for?(:title) ? content_for(:title) : DEFAULT_TITLE
  end

  def seo_description
    content_for?(:meta_description) ? content_for(:meta_description) : DEFAULT_DESCRIPTION
  end

  def seo_canonical_url
    if content_for?(:canonical_url)
      content_for(:canonical_url)
    else
      "#{request.base_url}#{request.path}"
    end
  end

  def seo_og_image_url
    if content_for?(:og_image)
      content_for(:og_image)
    else
      absolute_asset_url("landing/home.jpg")
    end
  end

  def seo_robots_content
    return content_for(:robots) if content_for?(:robots)
    return "noindex, nofollow" if seo_private_page?

    nil
  end

  def seo_private_page?
    return true if devise_controller?
    return true if controller_path.start_with?("admin/")
    return true if %w[checkouts bookings meeting_bookings].include?(controller_name)

    false
  end

  def seo_indexable_page?
    !seo_private_page?
  end

  def local_business_json_ld
    {
      "@context" => "https://schema.org",
      "@type" => [ "LocalBusiness", "CoworkingSpace" ],
      "name" => "Mezzanine",
      "legalName" => "Mesa Workspace, Lda.",
      "url" => "#{request.base_url}/",
      "image" => absolute_asset_url("landing/home.jpg"),
      "description" => DEFAULT_DESCRIPTION,
      "email" => "hello@mezzaninecowork.com",
      "address" => {
        "@type" => "PostalAddress",
        "streetAddress" => "Rua Brito e Cunha 27, R/C",
        "addressLocality" => "Matosinhos",
        "postalCode" => "4450-085",
        "addressCountry" => "PT"
      },
      "geo" => {
        "@type" => "GeoCoordinates",
        "latitude" => 41.18253087132666,
        "longitude" => -8.691271823268368
      },
      "openingHoursSpecification" => [
        {
          "@type" => "OpeningHoursSpecification",
          "dayOfWeek" => %w[Monday Tuesday Wednesday Thursday Friday],
          "opens" => "08:00",
          "closes" => "20:00"
        }
      ],
      "sameAs" => [
        "https://www.instagram.com/mezzanine.cowork/"
      ]
    }
  end

  private

  def absolute_asset_url(asset)
    path = path_to_image(asset)
    return path if path.start_with?("http://", "https://")

    "#{request.base_url}#{path}"
  end
end
