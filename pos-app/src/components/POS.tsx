import React from 'react';
import { Search, ScanLine, Minus, Plus, Trash2, ChevronLeft, Banknote, CreditCard, Smartphone, ShoppingCart, ChevronDown, Check } from 'lucide-react';
import type { Product, CartItem, Bill, BillItem, PaymentMode } from '../types';
import BillView from './BillView';
import QRScanner from './QRScanner';

interface POSProps {
  products: Product[];
  bills: Bill[];
  operators: string[];
  operatorName: string;
  onOperatorChange: (name: string) => void;
  nextBillNumber: () => Promise<string>;
  onBillSaved: (bill: Bill) => Promise<void>;
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

const PAY_ICONS: Record<PaymentMode, React.ReactNode> = {
  cash: <Banknote size={18} />,
  card: <CreditCard size={18} />,
  upi:  <Smartphone size={18} />,
};

const POS: React.FC<POSProps> = ({ products, bills, operators, operatorName, onOperatorChange, nextBillNumber, onBillSaved }) => {
  const [cart, setCart] = React.useState<CartItem[]>([]);
  const [search, setSearch] = React.useState('');
  const [selectedCategory, setSelectedCategory] = React.useState('');
  const [customerName, setCustomerName] = React.useState('');
  const [customerPhone, setCustomerPhone] = React.useState('');
  const [lookupStatus, setLookupStatus] = React.useState<'idle' | 'found' | 'new'>('idle');
  const [discount, setDiscount] = React.useState('');
  const [paymentMode, setPaymentMode] = React.useState<PaymentMode>('cash');
  const [savedBill, setSavedBill] = React.useState<Bill | null>(null);
  const [cartOpen, setCartOpen] = React.useState(false);
  const [scannerOpen, setScannerOpen] = React.useState(false);
  const [scanMsg, setScanMsg] = React.useState('');
  const [saving, setSaving] = React.useState(false);
  const [opDropOpen, setOpDropOpen] = React.useState(false);

  React.useEffect(() => {
    const digits = customerPhone.replace(/\D/g, '');
    if (digits.length >= 10) {
      const match = bills.find(b => b.customerPhone.replace(/\D/g, '') === digits && b.customerName);
      if (match) {
        setCustomerName(match.customerName);
        setLookupStatus('found');
      } else {
        setLookupStatus('new');
      }
    } else {
      setLookupStatus('idle');
    }
  }, [customerPhone, bills]);

  const categories = React.useMemo(() => {
    const cats = new Set<string>();
    products.forEach((p) => { if (p.category) cats.add(p.category); });
    return Array.from(cats).sort();
  }, [products]);

  const filtered = React.useMemo(() => {
    const q = search.trim().toLowerCase();
    return products
      .filter((p) => {
        const matchSearch = !q
          || p.name.toLowerCase().includes(q)
          || p.category.toLowerCase().includes(q)
          || (p.sku && p.sku.toLowerCase().includes(q));
        const matchCat = !selectedCategory || p.category === selectedCategory;
        return matchSearch && matchCat;
      })
      .sort((a, b) => (a.stock === 0 ? 1 : 0) - (b.stock === 0 ? 1 : 0));
  }, [products, search, selectedCategory]);

  const totals: Totals = React.useMemo(() => {
    const discountAmt = Math.max(0, parseFloat(discount) || 0);
    const rawItems = cart.map((ci) => {
      const rate = ci.product.gstRate;
      const taxableAmount = (ci.product.price * ci.quantity) / (1 + rate / 100);
      const cgst = (taxableAmount * rate) / 200;
      const sgst = cgst;
      return { productId: ci.product.id, taxableAmount, cgst, sgst, lineTotal: taxableAmount + cgst + sgst };
    });
    const rawSubtotal = rawItems.reduce((s, i) => s + i.taxableAmount, 0);
    // Discount reduces taxable base; GST scales proportionally with it
    const cappedDiscount = Math.min(discountAmt, rawSubtotal);
    const ratio = rawSubtotal > 0 ? (rawSubtotal - cappedDiscount) / rawSubtotal : 1;
    const itemTotals = rawItems.map(i => ({
      ...i,
      taxableAmount: i.taxableAmount * ratio,
      cgst: i.cgst * ratio,
      sgst: i.sgst * ratio,
      lineTotal: i.lineTotal * ratio,
    }));
    const totalCGST = itemTotals.reduce((s, i) => s + i.cgst, 0);
    const totalSGST = itemTotals.reduce((s, i) => s + i.sgst, 0);
    const totalGST = totalCGST + totalSGST;
    const grandTotal = (rawSubtotal - cappedDiscount) + totalGST;
    // Store raw subtotal so invoice can display: rawSubtotal − discount + discountedGST = grandTotal
    return { items: itemTotals, subtotal: rawSubtotal, totalCGST, totalSGST, totalGST, discountAmt: cappedDiscount, grandTotal };
  }, [cart, discount]);

  function addToCart(product: Product) {
    if (product.stock === 0) return;
    setCart((prev) => {
      const existing = prev.find((ci) => ci.product.id === product.id);
      if (existing) {
        if (product.stock !== undefined && existing.quantity >= product.stock) return prev;
        return prev.map((ci) => ci.product.id === product.id ? { ...ci, quantity: ci.quantity + 1 } : ci);
      }
      return [...prev, { product, quantity: 1 }];
    });
  }

  function updateQty(productId: string, delta: number) {
    setCart((prev) =>
      prev.map((ci) => {
        if (ci.product.id !== productId) return ci;
        if (delta > 0 && ci.product.stock !== undefined && ci.quantity >= ci.product.stock) return ci;
        return { ...ci, quantity: ci.quantity + delta };
      }).filter((ci) => ci.quantity > 0)
    );
  }

  function clearCart() {
    setCart([]);
    setCustomerName('');
    setCustomerPhone('');
    setLookupStatus('idle');
    setDiscount('');
    setPaymentMode('cash');
  }

  function handleQRScan(text: string) {
    setScannerOpen(false);
    // QR format: "KADA:{id}" (first line)
    const firstLine = text.split('\n')[0].trim();
    let product: Product | undefined;
    if (firstLine.startsWith('KADA:')) {
      const id = firstLine.slice(5);
      product = products.find((p) => p.id === id);
    } else {
      // fallback: match by name
      product = products.find((p) => p.name.toLowerCase() === firstLine.toLowerCase());
    }
    if (product) {
      if (product.stock === 0) {
        setScanMsg(`Out of stock: ${product.name}`);
      } else {
        addToCart(product);
        setScanMsg(`Added: ${product.name}`);
      }
    } else {
      setScanMsg('Product not found for this QR code.');
    }
    setTimeout(() => setScanMsg(''), 3000);
  }

  async function handleSaveBill() {
    if (cart.length === 0 || saving) return;
    setSaving(true);
    try {
      const billNumber = await nextBillNumber();
      const billItems: BillItem[] = cart.map((ci, idx) => {
        const t = totals.items[idx];
        return {
          productId: ci.product.id, name: ci.product.name, price: ci.product.price,
          quantity: ci.quantity, unit: ci.product.unit, gstRate: ci.product.gstRate,
          taxableAmount: t.taxableAmount, cgst: t.cgst, sgst: t.sgst, lineTotal: t.lineTotal,
        };
      });
      const bill: Bill = {
        id: crypto.randomUUID(),
        billNumber,
        date: new Date().toISOString(),
        items: billItems,
        operatorName,
        subtotal: totals.subtotal, totalCGST: totals.totalCGST, totalSGST: totals.totalSGST,
        totalGST: totals.totalGST, discount: totals.discountAmt, grandTotal: totals.grandTotal,
        customerName: customerName.trim(), customerPhone: customerPhone.trim(), paymentMode,
      };
      await onBillSaved(bill);
      setSavedBill(bill);
    } finally {
      setSaving(false);
    }
  }

  function handleBillViewClose() {
    setSavedBill(null);
    clearCart();
  }

  const totalItemCount = cart.reduce((sum, ci) => sum + ci.quantity, 0);

  return (
    <div className="pos-layout">
      {/* Left: Product Panel */}
      <div className="product-panel">
        <div className="pos-operator-bar">
          <span className="pos-operator-label">Operator</span>
          {operators.length > 0 ? (
            <div className="custom-select pos-operator-drop">
              <button
                type="button"
                className={`custom-select-trigger${opDropOpen ? ' open' : ''}`}
                onClick={() => setOpDropOpen(o => !o)}
              >
                <span className={operatorName ? '' : 'placeholder'}>{operatorName || '— Select —'}</span>
                <ChevronDown size={14} className={`custom-select-chevron${opDropOpen ? ' flipped' : ''}`} />
              </button>
              {opDropOpen && (
                <div className="custom-select-menu">
                  {operators.map(op => (
                    <button
                      key={op}
                      type="button"
                      className={`custom-select-option${operatorName === op ? ' selected' : ''}`}
                      onClick={() => { onOperatorChange(op); setOpDropOpen(false); }}
                    >
                      {op}
                      {operatorName === op && <Check size={13} />}
                    </button>
                  ))}
                </div>
              )}
            </div>
          ) : (
            <span className="pos-operator-empty">No operators — add in Settings</span>
          )}
        </div>

        <div className="search-bar">
          <Search size={16} color="var(--text-muted)" />
          <input
            type="text"
            placeholder="Search products..."
            value={search}
            onChange={(e) => setSearch(e.target.value)}
          />
          <button className="scan-btn" onClick={() => setScannerOpen(true)} title="Scan QR code">
            <ScanLine size={18} />
          </button>
        </div>

        {scanMsg && (
          <div className={`scan-toast${scanMsg.startsWith('Added') ? ' scan-toast-ok' : ' scan-toast-err'}`}>
            {scanMsg}
          </div>
        )}

        <div className="cat-tabs">
          <button className={`cat-tab${selectedCategory === '' ? ' active' : ''}`} onClick={() => setSelectedCategory('')}>All</button>
          {categories.map((cat) => (
            <button key={cat} className={`cat-tab${selectedCategory === cat ? ' active' : ''}`} onClick={() => setSelectedCategory(cat)}>{cat}</button>
          ))}
        </div>

        {cart.length > 0 && (
          <div className="mini-cart-bar" onClick={() => setCartOpen(true)}>
            <span className="mcb-left">
              <span className="mcb-dot" />
              {totalItemCount} item{totalItemCount !== 1 ? 's' : ''}
            </span>
            <span className="mcb-right">₹{totals.grandTotal.toFixed(2)} › View Cart</span>
          </div>
        )}

        <div className="product-grid">
          {filtered.length === 0 ? (
            <div className="empty-table" style={{ gridColumn: '1 / -1' }}>No products found.</div>
          ) : (
            filtered.map((product) => {
              const cartItem = cart.find(ci => ci.product.id === product.id);
              return (
                <div
                  key={product.id}
                  className={`product-card${cartItem ? ' in-cart' : ''}${product.stock === 0 ? ' out-of-stock' : ''}`}
                  onClick={() => addToCart(product)}
                >
                  {product.image && (
                    <div className="pc-img-wrap">
                      <img src={product.image} alt={product.name} className="pc-img" />
                      {cartItem && <span className="pc-img-badge">✓ {cartItem.quantity}</span>}
                    </div>
                  )}
                  <div className="pc-top">
                    {product.category ? <span className="prod-cat">{product.category}</span> : <span />}
                    {!product.image && cartItem && <span className="pc-badge">✓ {cartItem.quantity}</span>}
                  </div>
                  <div className="prod-name">
                    {product.sku && <span className="pc-sku">{product.sku}</span>}
                    {product.name}
                  </div>
                  {product.stock !== undefined && (
                    <div className={`pc-stock${product.stock === 0 ? ' pc-stock-out' : product.stock <= 5 ? ' pc-stock-low' : ' pc-stock-ok'}`}>
                      {product.stock === 0 ? 'Out of stock' : `${product.stock} left`}
                    </div>
                  )}
                  <div className="pc-bottom">
                    <span className="prod-price">₹{product.price.toFixed(2)}</span>
                    {cartItem ? (
                      <div className="pc-qty" onClick={e => e.stopPropagation()}>
                        <button className="pc-qty-btn" onClick={() => updateQty(product.id, -1)}><Minus size={12} /></button>
                        <span className="pc-qty-num">{cartItem.quantity}</span>
                        <button className="pc-qty-btn" onClick={() => updateQty(product.id, 1)}><Plus size={12} /></button>
                      </div>
                    ) : (
                      <span className="prod-gst">{product.gstRate > 0 ? `GST ${product.gstRate}%` : 'No GST'}</span>
                    )}
                  </div>
                </div>
              );
            })
          )}
        </div>
      </div>

      {/* Right: Cart Panel */}
      <div className={`cart-panel${cartOpen ? ' mobile-open' : ''}`}>
        <div className="cart-mobile-bar">
          <button onClick={() => setCartOpen(false)}><ChevronLeft size={22} /></button>
          <span>Cart ({totalItemCount} {totalItemCount === 1 ? 'item' : 'items'})</span>
        </div>

        <div className="cart-card">
          <div className="cart-header">
            <span className="cart-title">Cart</span>
            <span className="cart-count">{totalItemCount} {totalItemCount === 1 ? 'item' : 'items'}</span>
          </div>

          {cart.length === 0 ? (
            <div className="cart-empty">Tap any product to add it here.</div>
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
                      <button className="qty-btn" onClick={() => updateQty(ci.product.id, -1)}><Minus size={13} /></button>
                      <span className="qty-val">{ci.quantity}</span>
                      <button className="qty-btn" onClick={() => updateQty(ci.product.id, 1)}><Plus size={13} /></button>
                    </div>
                  </div>
                );
              })}
            </div>
          )}

          {cart.length > 0 && (
            <div className="bill-summary">
              <div className="summary-row">
                <span>Subtotal (Taxable)</span>
                <span>₹{totals.subtotal.toFixed(2)}</span>
              </div>
              <div className="summary-row discount-row">
                <span>Discount (₹)</span>
                <input
                  type="number" min="0" step="0.01"
                  value={discount} onChange={(e) => setDiscount(e.target.value)}
                  placeholder="0.00" className="discount-input"
                />
              </div>
              <div className="summary-row">
                <span>CGST</span>
                <span>₹{totals.totalCGST.toFixed(2)}</span>
              </div>
              <div className="summary-row">
                <span>SGST</span>
                <span>₹{totals.totalSGST.toFixed(2)}</span>
              </div>
              <div className="summary-row grand-total-row">
                <span><strong>Grand Total</strong></span>
                <span><strong>₹{totals.grandTotal.toFixed(2)}</strong></span>
              </div>
            </div>
          )}

          {/* Customer Info */}
          <div className="customer-row" style={{ flexDirection: 'column' }}>
            <input
              type="tel"
              placeholder="Mobile number"
              value={customerPhone}
              onChange={(e) => setCustomerPhone(e.target.value)}
              style={{ flex: 'none', width: '100%' }}
            />
            <div style={{ position: 'relative' }}>
              <input
                type="text"
                placeholder="Customer name *"
                value={customerName}
                onChange={(e) => setCustomerName(e.target.value)}
                style={{
                  flex: 'none', width: '100%',
                  paddingRight: lookupStatus !== 'idle' ? 90 : undefined,
                  ...(lookupStatus === 'found' ? { borderColor: 'var(--green)', background: 'var(--green-light)' } : {}),
                }}
              />
              {lookupStatus === 'found' && (
                <span style={{ position: 'absolute', right: 10, top: '50%', transform: 'translateY(-50%)',
                  fontSize: 10, color: 'var(--green)', fontWeight: 700, pointerEvents: 'none', whiteSpace: 'nowrap' }}>
                  ✓ Returning
                </span>
              )}
              {lookupStatus === 'new' && (
                <span style={{ position: 'absolute', right: 10, top: '50%', transform: 'translateY(-50%)',
                  fontSize: 10, color: 'var(--text-muted)', fontWeight: 600, pointerEvents: 'none', whiteSpace: 'nowrap' }}>
                  New customer
                </span>
              )}
            </div>
          </div>

          {/* Payment Modes */}
          <div className="payment-modes">
            {(['cash', 'card', 'upi'] as PaymentMode[]).map((mode) => (
              <button key={mode} className={`pay-mode-btn${paymentMode === mode ? ' active' : ''}`} onClick={() => setPaymentMode(mode)}>
                {PAY_ICONS[mode]}
                {mode.charAt(0).toUpperCase() + mode.slice(1)}
              </button>
            ))}
          </div>
        </div>

        <div className="action-btns">
          <button className="btn btn-ghost" onClick={clearCart} disabled={cart.length === 0}>
            <Trash2 size={15} style={{ marginRight: 4 }} />
            Clear
          </button>
          <button className="btn btn-primary" onClick={handleSaveBill} disabled={cart.length === 0 || saving || !customerName.trim()}>
            {saving ? 'Saving…' : 'Save & Print Bill'}
          </button>
        </div>
      </div>

      {/* Cart FAB (mobile only) */}
      {cart.length > 0 && !cartOpen && (
        <button className="cart-fab" onClick={() => setCartOpen(true)}>
          <span style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
            <ShoppingCart size={18} />
            {totalItemCount} {totalItemCount === 1 ? 'item' : 'items'}
          </span>
          <span>₹{totals.grandTotal.toFixed(2)} →</span>
        </button>
      )}

      {scannerOpen && <QRScanner onScan={handleQRScan} onClose={() => setScannerOpen(false)} />}

      {savedBill && <BillView bill={savedBill} shopName="" onClose={handleBillViewClose} />}
    </div>
  );
};

export default POS;
