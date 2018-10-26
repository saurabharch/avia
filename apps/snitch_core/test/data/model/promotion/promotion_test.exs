defmodule Snitch.Data.Schema.PromotionTest do
  use ExUnit.Case
  use Snitch.DataCase

  import Snitch.Factory

  alias Snitch.Data.Model.Promotion

  @params %{
    "code" => "INDEPENDENCE",
    "usage_limit" => 10,
    "starts_at" => DateTime.utc_now(),
    "expires_at" => Timex.shift(DateTime.utc_now(), years: 1),
    "match_policy" => "all",
    "active" => true
  }

  describe "create/1" do
    test "adds data successfully" do
      {:ok, result} = Promotion.create(@params)
      assert result.active == true
    end

    test "fails for duplicate code" do
      promotion = insert(:promotion)
      params = Map.put(@params, "code", promotion.code)

      {:error, changeset} = Promotion.create(params)

      assert changeset.valid? == false
      assert %{code: ["has already been taken"]} = errors_on(changeset)
    end
  end

  describe "update/2" do
    test "successfully" do
      promotion = insert(:promotion)
      params = %{"code" => "INDEPENDENCE"}
      {:ok, result} = Promotion.update(params, promotion)

      assert result.id == promotion.id
      assert result.code != promotion.code
    end
  end

  describe "delete/1" do
    test "successfully" do
      promotion = insert(:promotion)

      result = Promotion.get(promotion.id)
      refute is_nil(result)

      {:ok, _} = Promotion.delete(promotion.id)
      result = Promotion.get(promotion.id)
      assert is_nil(result)
    end
  end

  describe "get_all" do
    test "promotions" do
      insert_list(2, :promotion)
      promotions = Promotion.get_all()
      assert length(promotions) == 2
    end
  end

  test "load_promotion_manifest/0" do
    result = Promotion.load_promotion_manifest()
    display_list = Map.keys(result)
    assert length(display_list) == 2
  end
end