defmodule Snitch.Demo.Order do

  use Timex

  import Snitch.Tools.Helper.Order, only: [line_items_with_price: 2]

  alias Ecto.DateTime
  alias Snitch.Data.Schema.{LineItem, Order, ShippingCategory, StockLocation, User, Package, PackageItem, Product, Taxon}
  alias Snitch.Core.Tools.MultiTenancy.Repo

  require Logger

  @order %{
    number: nil,
    state: nil,
    user_id: nil,
    billing_address: nil,
    shipping_address: nil,
    inserted_at: Timex.now,
    updated_at: Timex.now
  }

  defp build_orders(start_time) do
    variants = Repo.all(Product)
    [user | _] = Repo.all(User)

    digest = [
      %{quantity: [5, 5, 1, 0, 0, 0, 0, 3, 0, 0, 0, 0, 0, 0, 0, 1], user_id: user.id, state: :confirmed},
      %{quantity: [0, 0, 0, 0, 0, 100], user_id: user.id, state: :confirmed},
      %{quantity: [5, 0, 8, 12, 0, 0, 0], user_id: user.id, state: :confirmed}
    ]

    make_orders(digest, variants, start_time)

  end

  def seeds do
    Repo.delete_all(Package)
    Repo.delete_all(Order)
    end_time = Timex.now
    start_time =  Timex.shift(end_time, months: -1)
    seed_orders(start_time)
  end

  def seed_orders(start_time) do
    end_time = Timex.now

    case Timex.before?(start_time, end_time) do
      true  ->
        seed_orders!(start_time)
      false ->
        nil
    end

  end

  def seed_orders!(start_time) do

    {orders, line_items} = build_orders(start_time)
    {count, order_structs} =
      Repo.insert_all(
        Order,
        orders,
        on_conflict: :nothing,
        conflict_target: [:number],
        returning: true
      )
    Logger.info("Inserted #{count} orders.")
    packages =
      order_structs
        |> Enum.map(fn order ->
          %{
            number: Nanoid.generate(),
            order_id: order.id,
            state: "pending",
            origin_id: Enum.random(Repo.all(StockLocation)).id,
            shipping_category_id: Enum.random(Repo.all(ShippingCategory)).id,
            inserted_at: start_time,
            updated_at: start_time
          }
        end)
    {count, package_structs} =
      Repo.insert_all(
        Package,
        packages,
        on_conflict: :nothing,
        conflict_target: [:number],
        returning: true
      )
    Logger.info("Created #{count} packages.")
    line_items =
      order_structs
      |> Stream.zip(line_items)
      |> Enum.map(fn {%{id: id}, items} ->
        Enum.map(items, &Map.put(&1, :order_id, id))
      end)
      |> List.flatten()

    {count, line_item_structs} = Repo.insert_all(LineItem, line_items, returning: true)

    Logger.info("Inserted #{count} line-items.")
    package_items =
      line_item_structs
        |> Repo.preload([order: :packages])
        |> Enum.map(fn item ->
          package = item.order.packages |> List.first()
          %{
            number: Nanoid.generate(),
            quantity: item.quantity,
            package_id: package.id,
            state: "pending",
            backordered?: true,
            product_id: item.product_id,
            line_item_id: item.id,
            inserted_at: start_time,
            updated_at: start_time
          }
        end)
    {count, package_item_structs} =
    Repo.insert_all(
      PackageItem,
      package_items,
      on_conflict: :nothing,
      conflict_target: [:number],
      returning: true
    )
    Logger.info("Created #{count} package_items.")
    start_time = Timex.shift(start_time, days: 1)
    seed_orders(start_time)
  end

  def make_orders(digest, variants, start_time) do
    digest
    |> Stream.with_index()
    |> Enum.map(fn {manifest, index} ->
      number = "#{Nanoid.generate()}-#{index}"
      line_items = line_items_with_price(variants, manifest.quantity)
      line_items = Enum.map(line_items, fn(line_item) ->
        line_item
        |> Map.put(:inserted_at, start_time)
        |> Map.put(:updated_at, start_time)
      end)
      order = %{
        @order
        | number: number,
          state: "#{manifest.state}",
          user_id: manifest[:user_id],
          billing_address: manifest[:address],
          shipping_address: manifest[:address],
          inserted_at: start_time,
          updated_at: start_time
      }

      {order, line_items}
    end)
    |> Enum.unzip()
  end

end
