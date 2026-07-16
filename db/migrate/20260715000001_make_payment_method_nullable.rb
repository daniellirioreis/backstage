class MakePaymentMethodNullable < ActiveRecord::Migration[7.1]
  def change
    change_column_null :payments, :payment_method, true
  end
end
