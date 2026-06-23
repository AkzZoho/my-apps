import React, { useRef, useState } from 'react';
import { Plus, QrCode, Printer, Trash2, CheckCircle, Clock, X, ArrowLeft, Package, ChevronDown } from 'lucide-react';
import QRCode from 'react-qr-code';
import type { Product, Purchase, PurchaseItem } from '../types';
import UnitSelect from './UnitSelect';

interface PurchaseScreenProps {
  purchases: Purchase[];
  products: Product[];
  nextPurchaseNumber: () => Promise<string>;
  onSave: (purchase: Purchase) => Promise<void>;
  onDelete: (id: string) => Promise<void>;
  onStatusUpdate: (id: string, status: 'pending' | 'received') => Promise<void>;
  units: string[];
  onAddUnit: (unit: string) => void;
}

interface FormItem {
  productId?: string;
  name: string;
  quantity: string;
  unit: string;
  pricePerUnit: string;
}

const MONTHS = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
function fmtDate(iso: string) { const d = new Date(iso); return `${d.getDate()} ${MONTHS[d.getMonth()]} ${d.getFullYear()}`; }
function fmtDelivery(s: string) { if (!s) return ''; const d = new Date(s); return `${d.getDate()} ${MONTHS[d.getMonth()]} ${d.getFullYear()}`; }


// ── Product lookup combobox ──────────────────────────────────
interface ComboboxProps {
  products: Product[];
  value: string;
  selectedId?: string;
  onSelect: (product: Product) => void;
  onManualChange: (name: string) => void;
  onClear: () => void;
}

const ProductCombobox: React.FC<ComboboxProps> = ({ products, value, selectedId, onSelect, onManualChange, onClear }) => {
  const [open, setOpen] = useState(false);

  const filtered = React.useMemo(() => {
    const q = value.trim().toLowerCase();
    if (!q) return products.slice(0, 8);
    return products.filter(
      p => p.name.toLowerCase().includes(q) || p.category.toLowerCase().includes(q)
    ).slice(0, 8);
  }, [products, value]);

  return (
    <div className="pr-combobox" style={{ flex: 3 }}>
      <div className="pr-combobox-wrap">
        <input
          className="pr-item-input"
          style={{ width: '100%', paddingRight: selectedId ? 28 : undefined }}
          type="text"
          value={value}
          placeholder="Search product or type name…"
          onChange={e => { onManualChange(e.target.value); setOpen(true); }}
          onFocus={() => setOpen(true)}
          onBlur={() => setTimeout(() => setOpen(false), 150)}
        />
        {selectedId && (
          <button className="pr-combobox-clear" onClick={onClear} title="Clear selection" type="button">
            <X size={12} />
          </button>
        )}
      </div>
      {open && filtered.length > 0 && !selectedId && (
        <div className="pr-combobox-menu">
          {filtered.map(p => (
            <button
              key={p.id}
              type="button"
              className="pr-combobox-option"
              onMouseDown={e => e.preventDefault()}
              onClick={() => { onSelect(p); setOpen(false); }}
            >
              <span className="pr-combobox-name">
                {p.sku && <span className="pr-combobox-sku">{p.sku}</span>}
                {p.name}
              </span>
              <span className="pr-combobox-meta">
                {p.category && <span className="pr-combobox-cat">{p.category}</span>}
                {p.stock !== undefined ? `${p.stock} ${p.unit} in stock` : p.unit}
              </span>
            </button>
          ))}
        </div>
      )}
    </div>
  );
};

// ── Main Screen ──────────────────────────────────────────────
const EMPTY_ITEM: FormItem = { name: '', quantity: '1', unit: '', pricePerUnit: '' };

const PurchaseScreen: React.FC<PurchaseScreenProps> = ({
  purchases, products, nextPurchaseNumber, onSave, onDelete, onStatusUpdate, units, onAddUnit,
}) => {
  const [view, setView] = useState<'list' | 'form'>('list');
  const [qrPurchase, setQrPurchase] = useState<Purchase | null>(null);
  const [saving, setSaving] = useState(false);
  const [supplierName, setSupplierName] = useState('');
  const [expectedDelivery, setExpectedDelivery] = useState('');
  const [notes, setNotes] = useState('');
  const [formItems, setFormItems] = useState<FormItem[]>([{ ...EMPTY_ITEM }]);
  const [expandedId, setExpandedId] = useState<string | null>(null);
  const printAreaRef = useRef<HTMLDivElement>(null);

  function openForm() {
    setSupplierName('');
    setExpectedDelivery('');
    setNotes('');
    setFormItems([{ ...EMPTY_ITEM }]);
    setView('form');
  }

  function selectProduct(idx: number, product: Product) {
    setFormItems(prev => prev.map((item, i) => i !== idx ? item : {
      productId: product.id,
      name: product.name,
      quantity: item.quantity || '1',
      unit: product.unit,
      pricePerUnit: item.pricePerUnit || String(product.price),
    }));
  }

  function clearProductSelection(idx: number) {
    setFormItems(prev => prev.map((item, i) => i !== idx ? item : { ...item, productId: undefined, name: '', unit: '' }));
  }

  function updateItemName(idx: number, name: string) {
    setFormItems(prev => prev.map((item, i) => i !== idx ? item : { ...item, productId: undefined, name }));
  }

  function updateItemField(idx: number, field: 'quantity' | 'unit' | 'pricePerUnit', value: string) {
    setFormItems(prev => prev.map((item, i) => i !== idx ? item : { ...item, [field]: value }));
  }

  function addItem() { setFormItems(prev => [...prev, { ...EMPTY_ITEM }]); }
  function removeItem(idx: number) { setFormItems(prev => prev.filter((_, i) => i !== idx)); }

  async function handleSave() {
    if (!supplierName.trim() || saving) return;
    const validItems = formItems.filter(i => i.name.trim());
    if (validItems.length === 0) return;
    setSaving(true);
    try {
      const prNumber = await nextPurchaseNumber();
      const purchaseItems: PurchaseItem[] = validItems.map(i => ({
        productId: i.productId,
        name: i.name.trim(),
        quantity: parseFloat(i.quantity) || 1,
        unit: i.unit.trim() || 'pcs',
        pricePerUnit: parseFloat(i.pricePerUnit) || 0,
      }));
      const totalAmount = purchaseItems.reduce((s, i) => s + i.quantity * i.pricePerUnit, 0);
      const purchase: Purchase = {
        id: crypto.randomUUID(),
        purchaseNumber: prNumber,
        date: new Date().toISOString(),
        supplierName: supplierName.trim(),
        expectedDelivery,
        notes: notes.trim(),
        items: purchaseItems,
        status: 'pending',
        totalAmount,
      };
      await onSave(purchase);
      setView('list');
    } finally {
      setSaving(false);
    }
  }

  async function handleDelete(id: string) {
    if (!window.confirm('Delete this purchase request?')) return;
    await onDelete(id);
    if (expandedId === id) setExpandedId(null);
  }

  async function toggleStatus(p: Purchase) {
    await onStatusUpdate(p.id, p.status === 'pending' ? 'received' : 'pending');
  }

  const formTotal = formItems.reduce(
    (s, i) => s + (parseFloat(i.quantity) || 0) * (parseFloat(i.pricePerUnit) || 0), 0
  );
  const formValid = supplierName.trim() && formItems.some(i => i.name.trim());

  // ── Form view ──
  if (view === 'form') {
    return (
      <div className="purchase-form-screen">
        <div className="screen-header">
          <button className="btn btn-ghost" style={{ gap: 6, display: 'flex', alignItems: 'center' }} onClick={() => setView('list')}>
            <ArrowLeft size={15} /> Back
          </button>
          <div className="screen-header-text" style={{ flex: 1, textAlign: 'center' }}>
            <h2>New Purchase Request</h2>
          </div>
          <div style={{ width: 80 }} />
        </div>

        <div className="purchase-form-card">
          <div className="form-grid">
            <div className="form-field">
              <label>Supplier Name *</label>
              <input type="text" value={supplierName} onChange={e => setSupplierName(e.target.value)} placeholder="e.g. ABC Traders" />
            </div>
            <div className="form-row">
              <div className="form-field">
                <label>Expected Delivery</label>
                <input type="date" value={expectedDelivery} onChange={e => setExpectedDelivery(e.target.value)} />
              </div>
              <div className="form-field">
                <label>Notes / Remarks</label>
                <input type="text" value={notes} onChange={e => setNotes(e.target.value)} placeholder="Optional" />
              </div>
            </div>
          </div>

          <div className="pr-items-section">
            <div className="pr-items-header">
              <span>Items</span>
              <button className="btn btn-ghost pr-add-item-btn" onClick={addItem}>
                <Plus size={13} /> Add Item
              </button>
            </div>

            <div className="pr-items-col-header">
              <span style={{ flex: 3 }}>Product</span>
              <span style={{ flex: 1 }}>Qty</span>
              <span style={{ flex: 1 }}>Unit</span>
              <span style={{ flex: 1.5 }}>Price/Unit (₹)</span>
              <span style={{ width: 28 }} />
            </div>

            {formItems.map((item, idx) => (
              <div key={idx} className="pr-item-row">
                <ProductCombobox
                  products={products}
                  value={item.name}
                  selectedId={item.productId}
                  onSelect={p => selectProduct(idx, p)}
                  onManualChange={name => updateItemName(idx, name)}
                  onClear={() => clearProductSelection(idx)}
                />
                <input
                  className="pr-item-input" style={{ flex: 1 }}
                  type="number" min="0" value={item.quantity}
                  onChange={e => updateItemField(idx, 'quantity', e.target.value)}
                />
                {item.productId ? (
                  <div className="pr-item-unit-lock" style={{ flex: 1 }}>{item.unit}</div>
                ) : (
                  <UnitSelect
                    value={item.unit}
                    onChange={v => updateItemField(idx, 'unit', v)}
                    units={units}
                    onAddUnit={onAddUnit}
                    placeholder="Unit"
                    style={{ flex: 1 }}
                  />
                )}
                <input
                  className="pr-item-input" style={{ flex: 1.5 }}
                  type="number" min="0" step="0.01" value={item.pricePerUnit}
                  onChange={e => updateItemField(idx, 'pricePerUnit', e.target.value)}
                  placeholder="0.00"
                />
                <button className="pr-item-del" onClick={() => removeItem(idx)} disabled={formItems.length === 1} title="Remove">
                  <X size={13} />
                </button>
              </div>
            ))}

            <div className="pr-items-total">Total: ₹{formTotal.toFixed(2)}</div>
          </div>

          <div style={{ display: 'flex', gap: 8, justifyContent: 'flex-end', marginTop: 8 }}>
            <button className="btn btn-ghost" onClick={() => setView('list')}>Cancel</button>
            <button className="btn btn-primary" onClick={handleSave} disabled={!formValid || saving}>
              {saving ? 'Saving…' : 'Create Request'}
            </button>
          </div>
        </div>
      </div>
    );
  }

  // ── List view ──
  return (
    <div>
      <div className="screen-header">
        <div className="screen-header-text">
          <h2>Purchase Requests</h2>
          <p>{purchases.length} total · {purchases.filter(p => p.status === 'pending').length} pending</p>
        </div>
        <button className="btn btn-primary" style={{ display: 'flex', alignItems: 'center', gap: 6 }} onClick={openForm}>
          <Plus size={15} /> New Request
        </button>
      </div>

      {purchases.length === 0 ? (
        <div className="no-bills" style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 12 }}>
          <Package size={40} color="var(--border)" />
          <div>No purchase requests yet.</div>
          <button className="btn btn-primary" onClick={openForm}><Plus size={14} /> Create First Request</button>
        </div>
      ) : (
        <div className="bill-list">
          {purchases.map(p => (
            <div key={p.id} className="pr-card">
              <div className="pr-card-main" onClick={() => setExpandedId(expandedId === p.id ? null : p.id)}>
                <div className="bill-card-left">
                  <div className="bill-card-top">
                    <span className="bill-num">{p.purchaseNumber}</span>
                    <span className={`pr-status-chip ${p.status}`}>
                      {p.status === 'received' ? <CheckCircle size={11} /> : <Clock size={11} />}
                      {p.status === 'received' ? 'Received' : 'Pending'}
                    </span>
                  </div>
                  <div className="bill-customer">{p.supplierName}</div>
                  <div className="bill-meta-text">
                    {fmtDate(p.date)} · {p.items.length} item{p.items.length !== 1 ? 's' : ''}
                    {p.expectedDelivery && ` · Delivery: ${fmtDelivery(p.expectedDelivery)}`}
                  </div>
                </div>
                <div className="bill-card-right">
                  <div className="bill-total">₹{p.totalAmount.toFixed(2)}</div>
                  <ChevronDown size={16} color="var(--text-muted)" style={{ transform: expandedId === p.id ? 'rotate(180deg)' : undefined, transition: '0.2s' }} />
                </div>
              </div>

              {expandedId === p.id && (
                <div className="pr-card-expanded">
                  <div className="pr-items-mini">
                    {p.items.map((item, i) => (
                      <div key={i} className="pr-mini-item">
                        <span className="pr-mini-name">{item.name}</span>
                        <span className="pr-mini-qty">{item.quantity} {item.unit}</span>
                        {item.pricePerUnit > 0 && (
                          <span className="pr-mini-price">₹{(item.quantity * item.pricePerUnit).toFixed(2)}</span>
                        )}
                      </div>
                    ))}
                  </div>
                  {p.notes && <div className="pr-notes">Note: {p.notes}</div>}
                  <div className="pr-card-actions">
                    <button
                      className={`btn ${p.status === 'pending' ? 'btn-primary' : 'btn-ghost'}`}
                      style={{ fontSize: 12, padding: '7px 14px', display: 'flex', alignItems: 'center', gap: 5 }}
                      onClick={() => toggleStatus(p)}
                    >
                      {p.status === 'pending'
                        ? <><CheckCircle size={13} /> Mark Received</>
                        : <><Clock size={13} /> Mark Pending</>}
                    </button>
                    {p.status === 'received' && (
                      <button
                        className="btn btn-ghost"
                        style={{ fontSize: 12, padding: '7px 14px', display: 'flex', alignItems: 'center', gap: 5 }}
                        onClick={() => setQrPurchase(p)}
                      >
                        <QrCode size={13} /> Print Labels
                      </button>
                    )}
                    <button
                      className="icon-btn del"
                      style={{ marginLeft: 'auto', display: 'flex', alignItems: 'center', gap: 4, padding: '7px 10px' }}
                      onClick={() => handleDelete(p.id)}
                    >
                      <Trash2 size={13} />
                    </button>
                  </div>
                </div>
              )}
            </div>
          ))}
        </div>
      )}

      {/* Product Labels Modal */}
      {qrPurchase && (
        <div className="modal-overlay" onClick={() => setQrPurchase(null)}>
          <div className="modal product-labels-modal" onClick={e => e.stopPropagation()}>
            <div className="modal-header no-print">
              <div>
                <h3 style={{ marginBottom: 2 }}>Product Labels</h3>
                <div style={{ fontSize: 12, color: 'var(--text-muted)' }}>
                  {qrPurchase.purchaseNumber} · {qrPurchase.supplierName} · {qrPurchase.items.length} item{qrPurchase.items.length !== 1 ? 's' : ''}
                </div>
              </div>
              <button className="modal-close" onClick={() => setQrPurchase(null)}><X size={18} /></button>
            </div>

            <div className="modal-body product-labels-body" ref={printAreaRef}>
              <div className="product-labels-grid">
                {qrPurchase.items.map((item, i) => {
                  const catalogProduct = item.productId ? products.find(p => p.id === item.productId) : undefined;
                  const qrValue = item.productId
                    ? `KADA:${item.productId}\n${item.name}\n₹${catalogProduct ? catalogProduct.price.toFixed(2) : '0.00'}/${item.unit}`
                    : `${item.name}\n${item.unit}`;
                  return (
                    <div key={i} className="pl-label">
                      {catalogProduct?.image && (
                        <img src={catalogProduct.image} alt={item.name} className="pl-label-img" />
                      )}
                      {catalogProduct?.category && (
                        <div className="pl-label-cat">{catalogProduct.category}</div>
                      )}
                      <div className="pl-label-name">{item.name}</div>
                      {catalogProduct && (
                        <div className="pl-label-price">₹{catalogProduct.price.toFixed(2)}</div>
                      )}
                      <div className="pl-label-sub">per {item.unit}{catalogProduct ? ` · GST ${catalogProduct.gstRate}%` : ''}</div>
                      <div className="pl-label-qr">
                        <QRCode value={qrValue} size={120} />
                      </div>
                      {(catalogProduct?.sku) && (
                        <div className="pl-label-sku">{catalogProduct.sku}</div>
                      )}
                      <div className="pl-label-hint">Scan with Kada POS</div>
                    </div>
                  );
                })}
              </div>
            </div>

            <div className="modal-footer no-print">
              <button className="btn btn-ghost" onClick={() => setQrPurchase(null)}>Close</button>
              <button className="btn btn-primary" style={{ display: 'flex', alignItems: 'center', gap: 6 }} onClick={() => window.print()}>
                <Printer size={15} /> Print All Labels
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};

export default PurchaseScreen;
