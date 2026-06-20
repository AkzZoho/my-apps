import type { Bill, Product } from './types';

const KEYS = {
  products: 'pos_products',
  bills: 'pos_bills',
  counter: 'pos_bill_counter',
  shopName: 'pos_shop_name',
};

function get<T>(key: string): T | null {
  try {
    const v = localStorage.getItem(key);
    return v ? (JSON.parse(v) as T) : null;
  } catch {
    return null;
  }
}

function set(key: string, value: unknown) {
  localStorage.setItem(key, JSON.stringify(value));
}

export const storage = {
  getProducts(): Product[] {
    return get<Product[]>(KEYS.products) ?? [];
  },
  saveProducts(products: Product[]) {
    set(KEYS.products, products);
  },

  getBills(): Bill[] {
    return get<Bill[]>(KEYS.bills) ?? [];
  },
  saveBill(bill: Bill) {
    const bills = this.getBills();
    bills.unshift(bill);
    set(KEYS.bills, bills);
  },
  deleteBill(id: string) {
    const bills = this.getBills().filter((b) => b.id !== id);
    set(KEYS.bills, bills);
  },

  nextBillNumber(): string {
    const count = (get<number>(KEYS.counter) ?? 0) + 1;
    set(KEYS.counter, count);
    return `BILL-${count.toString().padStart(4, '0')}`;
  },

  getShopName(): string {
    return get<string>(KEYS.shopName) ?? 'My Shop';
  },
  setShopName(name: string) {
    set(KEYS.shopName, name);
  },
};
