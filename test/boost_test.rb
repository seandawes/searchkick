require_relative "test_helper"

class BoostTest < Minitest::Test
  # conversions

  def test_conversions
    store [
      {name: "Tomato A", conversions: {"tomato" => 1}},
      {name: "Tomato B", conversions: {"tomato" => 2}},
      {name: "Tomato C", conversions: {"tomato" => 3}}
    ]
    assert_order "tomato", ["Tomato C", "Tomato B", "Tomato A"]
    assert_equal_scores "tomato", conversions: false
  end

  def test_multiple_conversions
    store [
      {name: "Speaker A", conversions_a: {"speaker" => 1}, conversions_b: {"speaker" => 6}},
      {name: "Speaker B", conversions_a: {"speaker" => 2}, conversions_b: {"speaker" => 5}},
      {name: "Speaker C", conversions_a: {"speaker" => 3}, conversions_b: {"speaker" => 4}}
    ], Speaker

    assert_equal_scores "speaker", {conversions: false}, Speaker
    assert_equal_scores "speaker", {}, Speaker
    assert_equal_scores "speaker", {conversions: ["conversions_a", "conversions_b"]}, Speaker
    assert_equal_scores "speaker", {conversions: ["conversions_b", "conversions_a"]}, Speaker
    assert_order "speaker", ["Speaker C", "Speaker B", "Speaker A"], {conversions: "conversions_a"}, Speaker
    assert_order "speaker", ["Speaker A", "Speaker B", "Speaker C"], {conversions: "conversions_b"}, Speaker
  end

  def test_multiple_conversions_with_boost_term
    store [
      {name: "Speaker A", conversions_a: {"speaker" => 4, "speaker_1" => 1}},
      {name: "Speaker B", conversions_a: {"speaker" => 3, "speaker_1" => 2}},
      {name: "Speaker C", conversions_a: {"speaker" => 2, "speaker_1" => 3}},
      {name: "Speaker D", conversions_a: {"speaker" => 1, "speaker_1" => 4}}
    ], Speaker

    assert_order "speaker", ["Speaker A", "Speaker B", "Speaker C", "Speaker D"], {conversions: "conversions_a"}, Speaker
    assert_order "speaker", ["Speaker D", "Speaker C", "Speaker B", "Speaker A"], {conversions: "conversions_a", conversions_term: "speaker_1"}, Speaker
  end

  def test_conversions_case
    store [
      {name: "Tomato A", conversions: {"tomato" => 1, "TOMATO" => 1, "tOmAtO" => 1}},
      {name: "Tomato B", conversions: {"tomato" => 2}}
    ]
    assert_order "tomato", ["Tomato A", "Tomato B"]
  end

  # global boost

  def test_boost
    store [
      {name: "Tomato A"},
      {name: "Tomato B", orders_count: 10},
      {name: "Tomato C", orders_count: 100}
    ]
    assert_order "tomato", ["Tomato C", "Tomato B", "Tomato A"], boost: "orders_count"
  end

  def test_boost_zero
    store [
      {name: "Zero Boost", orders_count: 0}
    ]
    assert_order "zero", ["Zero Boost"], boost: "orders_count"
  end

  def test_conversions_weight
    Product.reindex
    store [
      {name: "Product Boost", orders_count: 20},
      {name: "Product Conversions", conversions: {"product" => 10}}
    ]
    assert_order "product", ["Product Conversions", "Product Boost"], boost: "orders_count"
  end

  def test_boost_fields
    store [
      {name: "Red", color: "White"},
      {name: "White", color: "Red Red Red"}
    ]
    assert_order "red", ["Red", "White"], fields: ["name^10", "color"]
  end

  def test_boost_fields_decimal
    store [
      {name: "Red", color: "White"},
      {name: "White", color: "Red Red Red"}
    ]
    assert_order "red", ["Red", "White"], fields: ["name^10.5", "color"]
  end

  def test_boost_fields_word_start
    store [
      {name: "Red", color: "White"},
      {name: "White", color: "Red Red Red"}
    ]
    assert_order "red", ["Red", "White"], fields: [{"name^10" => :word_start}, "color"]
  end

  # for issue #855
  def test_apostrophes
    store_names ["Valentine's Day Special"]
    assert_search "Valentines", ["Valentine's Day Special"], fields: ["name^5"]
    assert_search "Valentine's", ["Valentine's Day Special"], fields: ["name^5"]
    assert_search "Valentine", ["Valentine's Day Special"], fields: ["name^5"]
  end

  def test_boost_by
    store [
      {name: "Tomato A"},
      {name: "Tomato B", orders_count: 10},
      {name: "Tomato C", orders_count: 100}
    ]
    assert_order "tomato", ["Tomato C", "Tomato B", "Tomato A"], boost_by: [:orders_count]
    assert_order "tomato", ["Tomato C", "Tomato B", "Tomato A"], boost_by: {orders_count: {factor: 10}}
    assert_order_relation ["Tomato C", "Tomato B", "Tomato A"], Product.search("tomato", relation: true).boost_by(orders_count: {factor: 10})
  end

  def test_boost_by_missing
    store [
      {name: "Tomato A"},
      {name: "Tomato B", orders_count: 10},
    ]

    assert_order "tomato", ["Tomato A", "Tomato B"], boost_by: {orders_count: {missing: 100}}
  end

  def test_boost_by_boost_mode_multiply
    store [
      {name: "Tomato A", found_rate: 0.9},
      {name: "Tomato B"},
      {name: "Tomato C", found_rate: 0.5}
    ]

    assert_order "tomato", ["Tomato B", "Tomato A", "Tomato C"], boost_by: {found_rate: {boost_mode: "multiply"}}
  end

  def test_boost_where
    store [
      {name: "Tomato A"},
      {name: "Tomato B", user_ids: [1, 2]},
      {name: "Tomato C", user_ids: [3]}
    ]
    assert_first "tomato", "Tomato B", boost_where: {user_ids: 2}
    assert_first "tomato", "Tomato B", boost_where: {user_ids: 1..2}
    assert_first "tomato", "Tomato B", boost_where: {user_ids: [1, 4]}
    assert_first "tomato", "Tomato B", boost_where: {user_ids: {value: 2, factor: 10}}
    assert_first "tomato", "Tomato B", boost_where: {user_ids: {value: [1, 4], factor: 10}}
    assert_order "tomato", ["Tomato C", "Tomato B", "Tomato A"], boost_where: {user_ids: [{value: 1, factor: 10}, {value: 3, factor: 20}]}

    assert_first_relation "Tomato B", Product.search("tomato", relation: true).boost_where(user_ids: 2)
  end

  def test_boost_where_negative_boost
    store [
      {name: "Tomato A"},
      {name: "Tomato B", user_ids: [2]},
      {name: "Tomato C", user_ids: [2]}
    ]
    assert_first "tomato", "Tomato A", boost_where: {user_ids: {value: 2, factor: 0.5}}
  end

  def test_boost_by_recency
    store [
      {name: "Article 1", created_at: 2.days.ago},
      {name: "Article 2", created_at: 1.day.ago},
      {name: "Article 3", created_at: Time.now}
    ]
    assert_order "article", ["Article 3", "Article 2", "Article 1"], boost_by_recency: {created_at: {scale: "7d", decay: 0.5}}
    assert_order_relation ["Article 3", "Article 2", "Article 1"], Product.search("article", relation: true).boost_by_recency(created_at: {scale: "7d", decay: 0.5})
  end

  def test_boost_by_recency_origin
    store [
      {name: "Article 1", created_at: 2.days.ago},
      {name: "Article 2", created_at: 1.day.ago},
      {name: "Article 3", created_at: Time.now}
    ]
    assert_order "article", ["Article 1", "Article 2", "Article 3"], boost_by_recency: {created_at: {origin: 2.days.ago, scale: "7d", decay: 0.5}}
  end

  def test_boost_by_distance
    store [
      {name: "San Francisco", latitude: 37.7833, longitude: -122.4167},
      {name: "San Antonio", latitude: 29.4167, longitude: -98.5000},
      {name: "San Marino", latitude: 43.9333, longitude: 12.4667}
    ]
    assert_order "san", ["San Francisco", "San Antonio", "San Marino"], boost_by_distance: {field: :location, origin: [37, -122], scale: "1000mi"}
    assert_order_relation ["San Francisco", "San Antonio", "San Marino"], Product.search("san", relation: true).boost_by_distance(field: :location, origin: [37, -122], scale: "1000mi")
  end

  def test_boost_by_distance_hash
    store [
      {name: "San Francisco", latitude: 37.7833, longitude: -122.4167},
      {name: "San Antonio", latitude: 29.4167, longitude: -98.5000},
      {name: "San Marino", latitude: 43.9333, longitude: 12.4667}
    ]
    assert_order "san", ["San Francisco", "San Antonio", "San Marino"], boost_by_distance: {field: :location, origin: {lat: 37, lon: -122}, scale: "1000mi"}
  end

  def test_boost_by_distance_v2
    store [
      {name: "San Francisco", latitude: 37.7833, longitude: -122.4167},
      {name: "San Antonio", latitude: 29.4167, longitude: -98.5000},
      {name: "San Marino", latitude: 43.9333, longitude: 12.4667}
    ]
    assert_order "san", ["San Francisco", "San Antonio", "San Marino"], boost_by_distance: {location: {origin: [37, -122], scale: "1000mi"}}
    assert_order_relation ["San Francisco", "San Antonio", "San Marino"], Product.search("san", relation: true).boost_by_distance(location: {origin: [37, -122], scale: "1000mi"})
  end

  def test_boost_by_distance_v2_hash
    store [
      {name: "San Francisco", latitude: 37.7833, longitude: -122.4167},
      {name: "San Antonio", latitude: 29.4167, longitude: -98.5000},
      {name: "San Marino", latitude: 43.9333, longitude: 12.4667}
    ]
    assert_order "san", ["San Francisco", "San Antonio", "San Marino"], boost_by_distance: {location: {origin: {lat: 37, lon: -122}, scale: "1000mi"}}
  end

  def test_boost_by_distance_v2_factor
    store [
      {name: "San Francisco", latitude: 37.7833, longitude: -122.4167, found_rate: 0.1},
      {name: "San Antonio", latitude: 29.4167, longitude: -98.5000, found_rate: 0.99},
      {name: "San Marino", latitude: 43.9333, longitude: 12.4667, found_rate: 0.2}
    ]

    assert_order "san", ["San Antonio","San Francisco", "San Marino"], boost_by: {found_rate: {factor: 100}}, boost_by_distance: {location: {origin: [37, -122], scale: "1000mi"}}
    assert_order "san", ["San Francisco", "San Antonio", "San Marino"], boost_by: {found_rate: {factor: 100}}, boost_by_distance: {location: {origin: [37, -122], scale: "1000mi", factor: 100}}
  end

  def test_boost_by_indices
    skip if cequel?

    store_names ["Rex"], Animal
    store_names ["Rexx"], Product

    assert_order "Rex", ["Rexx", "Rex"], {models: [Animal, Product], indices_boost: {Animal => 1, Product => 200}, fields: [:name]}, Searchkick
  end
end
