import React from 'react';
import type { Product, CartItem, Bill, BillItem, PaymentMode } from '../types';
import { storage } from '../storage';
import BillView from './BillView';

interface POSProps {
  products: Product[];
  onBillSaved: () => void;
}

interface Totals {
  items: {
    productId: string;
    taxableAmount: number;
    cgst: number;
    sgst: number;
    lineTotal: number;
  }[];
  subtotal: number;
  totalCGST: number;
  totalSGST: number;
  totalGST: number;
  discountAmt: number;
  grandTotal: number;
}

const POS: React.FC<POSProps> = ({ products, onBillSaved }) => {
  const [cart, setCart] = React.useState<CartItem[]>([]);
  const [search, setSearch] = React.useState('');
  const [selectedCategory, setSelectedCategory] = React.useState('');
  const [customerName, setCustomerName] = React.useState('');
  const [customerPhone, setCustomerPhone] = React.useState('');
  const [discount, setDiscount] = React.useState('');
  const [paymentMode, setPaymentMode] = React.useState<PaymentMode>('cash');
  const [savedBill, setSavedBill] = React.useState<Bill | null>(null);
  const [shopName] = React.useState(() => storage.getShopName());

  const categories = React.useMemo(() => {
    const cats = new Set<string>();
    products.forEach((p) => { if (p.category) cats.add(p.category); });
    return Array.from(cats).sort();
  }, [products]);

  const filtered = React.useMemo(() => {
    const q = search.trim().toLowerCase();
    return products.filter((p) => {
      const matchSearch = !q || p.name.toLowerCase().includes(q) || p.category.toLowerCase().includes(q);
      const matchCat = !selectedCategory || p.category === selectedCategory;
      return matchSearch && matchCat;
    });
  }, [products, search, selectedCategory]);

  const totals: Totals = React.useMemo(() => {
    const discountAmt = Math.max(0, parseFloat(discount) || 0);
    const itemTotals = cart.map((ci) => {
      const rate = ci.product.gstRate;
      const taxableAmount = (ci.product.price * ci.quantity) / (1 + rate / 100);
      const cgst = (taxableAmount * rate) / 200;
      const sgst = (taxableAmount * rate) / 200;
      const lineTotal = taxableAmount + cgst + sgst;
      return { productId: ci.product.id, taxableAmount, cgst, sgst, lineTotal };
    });
    const subtotal = itemTotals.reduce((s, i) => s + i.taxableAmount, 0);
    const totalCGST = itemTotals.reduce((s, i) => s + i.cgst, 0);
    const totalSGST = itemTotals.reduce((s, i) => s + i.sgst, 0);
    const totalGST = totalCGST + totalSGST;
    const grandTotal = Math.max(0, subtotal + totalGST - discountAmt);
    return { items: itemTotals, subtotal, totalCGST, totalSGST, totalGST, discountAmt, grandTotal };
  }, [cart, discount]);

  function addToCart(product: Product) {
    setCart((prev) => {
      const existing = prev.find((ci) => ci.product.id === product.id);
      if (existing) return prev.map((ci) => ci.product.id === product.id ? { ...ci, quantity: ci.quantity + 1 } : ci);
      return [...prev, { product, quantity: 1 }];
    });
  }

  function updateQty(productId: string, delta: number) {
    setCart((prev) => prev
      .map((ci) => ci.product.id === productId ? { ...ci, quantity: ci.quantity + delta } : ci)
      .filter((ci) => ci.quantity > 0)
    );
  }

  function clearCart() {
    setCart([]);
    setCustomerName('');
    setCustomerPhone('');
    setDiscount('');
    setPaymentMode('cash');
  }

  function handleSaveBill() {
    if (cart.length === 0) return;
    const billItems: BillItem[] = cart.map((ci, idx) => {
      const t = totals.items[idx];
      return {
        productId: ci.product.id, name: ci.product.name, price: ci.product.price,
        quantity: ci.quantity, unit: ci.product.unit, gstRate: ci.product.gstRate,
        taxableAmount: t.taxableAmount, cgst: t.cgst, sgst: t.sgst, lineTotal: t.lineTotal,
      };
    });
    const bill: Bill = {
      id: crypto.randomUUID(), billNumber: storage.nextBillNumber(),
      date: new Date().toISOString(), items: billItems,
      subtotal: totals.subtotal, totalCGST: totals.totalCGST, totalSGST: totals.totalSGST,
      totalGST: totals.totalGST, discount: totals.discountAmt, grandTotal: totals.grandTotal,
      customerName: customerName.trim(), customerPhone: customerPhone.trim(), paymentMode,
    };
    storage.saveBill(bill);
    setSavedBill(bill);
    onBillSaved();
  }

  const totalItemCount = cart.reduce((s, ci) => s + ci.quantity, 0);

  return (
    <div className="pos-layout">
      <div className="product-panel">
        <div className="search-bar">
          <input type="text" placeholder="Search products..." value={search} onChange={(e) => setSearch(e.target.value)} />
        </div>
        <div className="cat-tabs">
          <button className={`cat-tab${selectedCategory === '' ? ' active' : ''}`} onClick={() => setSelectedCategory('')}>All</button>
          {categories.map((cat) => (
            <button key={cat} className={`cat-tab${selectedCategory === cat ? ' active' : ''}`} onClick={() => setSelectedCategory(cat)}>{cat}</button>
          ))}
        </div>
        <div className="product-grid">
          {filtered.length === 0 ? (
            <div className="no-products">No products found. Add products first.</div>
          ) : (
            filtered.map((product) => (
              <div key={product.id} className="product-card" onClick={() => addToCart(product)}>
                {product.category && <div className="product-category">{product.category}</div>}
                <div className="product-name">{product.name}</div>
                <div className="product-price">₹{product.price.toFixed(2)}</div>
                <div className="product-unit">per {product.unit}</div>
              </div>
            ))
          )}
        </div>
      </div>

      <div className="cart-panel">
        <div className="cart-card">
          <div className="customer-row">
            <input type="text" placeholder="Customer Name" value={customerName} onChange={(e) => setCustomerName(e.target.value)} />
            <input type="tel" placeholder="Phone" value={customerPhone} onChange={(e) => setCustomerPhone(e.target.value)} />
          </div>
          <div className="cart-header">
            <span className="cart-title">Cart</span>
            <span className="cart-count">{totalItemCount} {totalItemCount === 1 ? 'item' : 'items'}</span>
          </div>
          {cart.length === 0 ? (
            <div className="cart-empty">Tap a product to add it to cart.</div>
          ) : (
            <div className="cart-items">
              {cart.map((ci) => {
                const t = totals.items.find((i) => i.productId === ci.product.id);
                return (
                  <div key={ci.product.id} className="cart-item">
                    <div className="cart-item-info">
                      <span className="cart-item-name">{ci.product.name}</span>
                      <span className="cart-item-price">₹{t ? t.lineTotal.toFixed(2) : '0.00'}</span>
                    </div>
                    <div className="cart-item-controls">
                      <button className="qty-btn" onClick={() => updateQty(ci.product.id, -1)}>−</button>
                      <span className="qty-val">{ci.quantity}</span>
                      <button className="qty-btn" onClick={() => updateQty(ci.product.id, 1)}>+</button>
                    </div>
                  </div>
                );
              })}
            </div>
          )}
          {cart.length > 0 && (
            <div className="bill-summary">
              <div className="summary-row"><span>Subtotal (Taxable)</span><span>₹{totals.subtotal.toFixed(2)}</span></div>
              <div className="summary-row"><span>CGST</span><span>₹{totals.totalCGST.toFixed(2)}</span></div>
              <div className="summary-row"><span>SGST</span><span>₹{totals.totalSGST.toFixed(2)}</span></div>
              <div className="summary-row discount-row">
                <span>Discount (₹)</span>
                <input type="number" min="0" step="0.01" value={discount} onChange={(e) => setDiscount(e.target.value)} placeholder="0.00" className="discount-input" />
              </div>
              <div className="summary-row grand-total-row">
                <span><strong>Grand Total</strong></span>
                <span><strong>₹{totals.grandTotal.toFixed(2)}</strong></span>
              </div>
            </div>
          )}
          <div className="payment-modes">
            {(['cash', 'card', 'upi'] as PaymentMode[]).map((mode) => (
              <button key={mode} className={`pay-mode-btn${paymentMode === mode ? ' active' : ''}`} onClick={() => setPaymentMode(mode)}>
                {mode === 'cash' && '💵 '}{mode === 'card' && '💳 '}{mode === 'upi' && '📱 '}
                {mode.charAt(0).toUpperCase() + mode.slice(1)}
              </button>
            ))}
          </div>
        </div>
        <div className="action-btns">
          <button className="btn btn-ghost" onClick={clearCart} disabled={cart.length === 0}>Clear</button>
          <button className="btn btn-primary" onClick={handleSaveBill} disabled={cart.length === 0}>Save &amp; Print Bill</button>
        </div>
      </div>

      {savedBill && (
        <BillView bill={savedBill} shopName={shopName} onClose={() => { setSavedBill(null); clearCart(); }} />
      )}
    </div>
  );
};

export default POS;
