export type GSTRate = 0 | 5 | 12 | 18 | 28;
export type PaymentMode = 'cash' | 'card' | 'upi';
export type Screen = 'pos' | 'products' | 'history';

export interface Product {
  id: string;
  name: string;
  price: number;
  unit: string;
  gstRate: GSTRate;
  category: string;
}

export interface CartItem {
  product: Product;
  quantity: number;
}

export interface BillItem {
  productId: string;
  name: string;
  price: number;
  quantity: number;
  unit: string;
  gstRate: number;
  taxableAmount: number;
  cgst: number;
  sgst: number;
  lineTotal: number;
}

export interface Bill {
  id: string;
  billNumber: string;
  date: string;
  items: BillItem[];
  subtotal: number;
  totalCGST: number;
  totalSGST: number;
  totalGST: number;
  discount: number;
  grandTotal: number;
  customerName: string;
  customerPhone: string;
  paymentMode: PaymentMode;
}
