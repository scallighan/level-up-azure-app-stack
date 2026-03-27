from dataclasses import dataclass
from datetime import datetime
from decimal import Decimal
from typing import Optional
from uuid import UUID


@dataclass(slots=True)
class AccountStocks:
	id: Optional[int] = None
	account_id: Optional[int] = None
	stock_id: Optional[int] = None
	purchase_order_id: Optional[int] = None
	purchase_date_time: Optional[datetime] = None
	shares_purchased: Optional[Decimal] = None
	notes: Optional[str] = None
	created_date: Optional[datetime] = None
	modified_date: Optional[datetime] = None
	purchase_price: Optional[Decimal] = None
	initial_investment: Optional[Decimal] = None
	stock_symbol: Optional[str] = None


@dataclass(slots=True)
class Beneficiaries:
	id: Optional[int] = None
	account_id: Optional[int] = None
	full_name: Optional[str] = None
	bank_code: Optional[str] = None
	bank_name: Optional[str] = None
	created_date: Optional[datetime] = None
	modified_date: Optional[datetime] = None


@dataclass(slots=True)
class Currencies:
	id: Optional[int] = None
	code: Optional[str] = None
	display_name: Optional[str] = None
	is_active: Optional[bool] = None


@dataclass(slots=True)
class OrderStatus:
	status_id: Optional[int] = None
	status_name: Optional[str] = None
	created_date: Optional[datetime] = None
	modified_date: Optional[datetime] = None


@dataclass(slots=True)
class PaymentMethods:
	id: Optional[int] = None
	account_id: Optional[int] = None
	type: Optional[str] = None
	activation_date: Optional[datetime] = None
	expiration_date: Optional[datetime] = None
	available_balance: Optional[Decimal] = None
	card_number: Optional[str] = None
	created_date: Optional[datetime] = None
	modified_date: Optional[datetime] = None


@dataclass(slots=True)
class PaymentMethodTypes:
	id: Optional[int] = None
	code: Optional[str] = None
	display_name: Optional[str] = None
	is_active: Optional[bool] = None


@dataclass(slots=True)
class Payments:
	payment_id: Optional[int] = None
	description: Optional[str] = None
	recipient_name: Optional[str] = None
	recipient_bank_code: Optional[str] = None
	account_id: Optional[int] = None
	payment_method_id: Optional[int] = None
	payment_type: Optional[str] = None
	amount: Optional[Decimal] = None
	timestamp: Optional[datetime] = None
	created_date: Optional[datetime] = None


@dataclass(slots=True)
class PurchaseOrders:
	purchase_order_id: Optional[int] = None
	purchase_order_number: Optional[str] = None
	account_id: Optional[int] = None
	payment_method_id: Optional[int] = None
	order_date: Optional[datetime] = None
	actual_delivery_date: Optional[datetime] = None
	status_id: Optional[int] = None
	sub_total: Optional[Decimal] = None
	tax_amount: Optional[Decimal] = None
	shipping_cost: Optional[Decimal] = None
	total_amount: Optional[Decimal] = None
	notes: Optional[str] = None
	created_date: Optional[datetime] = None
	modified_date: Optional[datetime] = None


@dataclass(slots=True)
class Stocks:
	id: Optional[int] = None
	stock_symbol: Optional[str] = None
	created_date: Optional[datetime] = None
	modified_date: Optional[datetime] = None
	company_name: Optional[str] = None


@dataclass(slots=True)
class Transactions:
	id: Optional[UUID] = None
	description: Optional[str] = None
	transaction_type_code: Optional[str] = None
	recipient_name: Optional[str] = None
	recipient_bank_reference: Optional[str] = None
	account_id: Optional[int] = None
	payment_type: Optional[str] = None
	amount: Optional[Decimal] = None
	timestamp: Optional[datetime] = None
	created_date: Optional[datetime] = None


@dataclass(slots=True)
class TransactionTypes:
	id: Optional[int] = None
	code: Optional[str] = None
	display_name: Optional[str] = None
	is_active: Optional[bool] = None


@dataclass(slots=True)
class User:
	user_name: Optional[str] = None
	created_date: Optional[datetime] = None
	modified_date: Optional[datetime] = None
	active: Optional[int] = None


@dataclass(slots=True)
class DatabaseFirewallRules:
	id: Optional[int] = None
	name: Optional[str] = None
	start_ip_address: Optional[str] = None
	end_ip_address: Optional[str] = None
	create_date: Optional[datetime] = None
	modify_date: Optional[datetime] = None


@dataclass(slots=True)
class Accounts:
	id: Optional[int] = None
	user_name: Optional[str] = None
	account_holder_full_name: Optional[str] = None
	currency: Optional[str] = None
	activation_date: Optional[datetime] = None
	balance: Optional[Decimal] = None
	created_date: Optional[datetime] = None
	modified_date: Optional[datetime] = None
