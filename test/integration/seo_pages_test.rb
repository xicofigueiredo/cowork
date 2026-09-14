require "test_helper"

class SeoPagesTest < ActionDispatch::IntegrationTest
  test "home page includes seo meta and structured data" do
    get root_path

    assert_response :success
    assert_select "html[lang=?]", "en"
    assert_select "meta[name=description]"
    assert_select "link[rel=canonical]"
    assert_select "meta[property='og:title']"
    assert_select "meta[name='twitter:card']"
    assert_select "script[type='application/ld+json']"
    assert_select "h1", text: /Mezzanine/
    assert_select "meta[name=robots]", count: 0
  end

  test "private pages are noindexed" do
    get new_user_session_path

    assert_response :success
    assert_select "meta[name=robots][content=?]", "noindex, nofollow"
    assert_select "script[type='application/ld+json']", count: 0
  end

  test "location page exposes address copy" do
    get location_path

    assert_response :success
    assert_match(/Rua Brito e Cunha 27/, response.body)
    assert_match(/08:00–20:00/, response.body)
  end

  test "robots and sitemap are publicly available" do
    get "/robots.txt"
    assert_response :success
    assert_match(/Sitemap: https:\/\/mezzaninecowork.com\/sitemap.xml/, response.body)

    get "/sitemap.xml"
    assert_response :success
    assert_match(/https:\/\/mezzaninecowork.com\/our-space/, response.body)
  end
end
