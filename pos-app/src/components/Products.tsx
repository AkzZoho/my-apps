import React from 'react';
import { QRCodeSVG } from 'qrcode.react';
import type { Product, GSTRate } from '../types';

interface ProductsProps {
  products: Product[];
  onUpdate: (products: Product[]) => void;
}

const UNITS = ['piece', 'kg', 'g', 'litre', 'ml', 'box', 'set'];
const GST_RATES: GSTRate[] = [0, 5, 12, 18, 28];

interface FormState {
  name: string;
  category: string;
  price: string;
  unit: string;
  gstRate: string;
}

const EMPTY_FORM: FormState = {
  name: '',
  category: '',
  price: '',
  unit: 'piece',
  gstRate: '0',
};

function qrData(p: Product): string {
  return `${p.name}\n₹${p.price.toFixed(2)} / ${p.unit}\nGST: ${p.gstRate}%${p.category ? `\n${p.category}` : ''}`;
}

const Products: React.FC<ProductsProps> = ({ products, onUpdate }) => {
  const [modalOpen, setModalOpen] = React.useState(false);
  const [editingProduct, setEditingProduct] = React.useState<Product | null>(null);
  const [form, setForm] = React.useState<FormState>(EMPTY_FORM);
  const [error, setError] = React.useState('');
  const [qrProduct, setQrProduct] = React.useState<Product | null>(null);

  function openAdd() {
    setEditingProduct(null);
    setForm(EMPTY_FORM);
    setError('');
    setModalOpen(true);
  }

  function openEdit(product: Product) {
    setEditingProduct(product);
    setForm({
      name: product.name,
      category: product.category,
      price: String(product.price),
      unit: product.unit,
      gstRate: String(product.gstRate),
    });
    setError('');
    setModalOpen(true);
  }

  function closeModal() {
    setModalOpen(false);
    setEditingProduct(null);
    setForm(EMPTY_FORM);
    setError('');
  }

  function handleField(field: keyof FormState, value: string) {
    setForm((prev) => ({ ...prev, [field]: value }));
  }

  function handleSave() {
    const name = form.name.trim();
    const price = parseFloat(form.price);
    if (!name) { setError('Product name is required.'); return; }
    if (!form.price || isNaN(price) || price < 0) { setError('A valid price is required.'); return; }

    const productData: Product = {
      id: editingProduct ? editingProduct.id : crypto.randomUUID(),
      name,
      category: form.category.trim(),
      price,
      unit: form.unit,
      gstRate: parseInt(form.gstRate, 10) as GSTRate,
    };

    if (editingProduct) {
      onUpdate(products.map((p) => (p.id === editingProduct.id ? productData : p)));
    } else {
      onUpdate([...products, productData]);
    }
    closeModal();
  }

  function handleDelete(id: string) {
    if (window.confirm('Delete this product?')) {
      onUpdate(products.filter((p) => p.id !== id));
    }
  }

  return (
    <div className="screen">
      <div className="screen-header">
        <div className="screen-header-text">
          <h2>Products</h2>
          <p>{products.length} item{products.length !== 1 ? 's' : ''} in catalog</p>
        </div>
        <button className="btn btn-gold" onClick={openAdd}>+ Add Product</button>
      </div>

      <div className="table-card">
        {products.length === 0 ? (
          <div className="empty-table">
            <div style={{ fontSize: 32 }}>📦</div>
            <p>No products yet. Add your first product!</p>
          </div>
        ) : (
          <table>
            <thead>
              <tr>
                <th>Name</th>
                <th>Category</th>
                <th>Price</th>
                <th>Unit</th>
                <th>GST Rate</th>
                <th>Actions</th>
              </tr>
            </thead>
            <tbody>
              {products.map((product) => (
                <tr key={product.id}>
                  <td style={{ fontWeight: 600 }}>{product.name}</td>
                  <td>
                    {product.category
                      ? <span className="cat-badge">{product.category}</span>
                      : <span style={{ color: '#aaa' }}>—</span>}
                  </td>
                  <td style={{ fontWeight: 600 }}>₹{product.price.toFixed(2)}</td>
                  <td style={{ color: 'var(--text-muted)' }}>{product.unit}</td>
                  <td><span className="gst-badge">{product.gstRate}%</span></td>
                  <td>
                    <div className="row-actions">
                      <button className="icon-btn edit" title="QR Label" onClick={() => setQrProduct(product)}>QR</button>
                      <button className="icon-btn edit" title="Edit" onClick={() => openEdit(product)}>✏️</button>
                      <button className="icon-btn del" title="Delete" onClick={() => handleDelete(product.id)}>🗑️</button>
                    </div>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </div>

      {modalOpen && (
        <div className="modal-overlay" onClick={closeModal}>
          <div className="modal" onClick={(e) => e.stopPropagation()}>
            <div className="modal-header">
              <h3>{editingProduct ? 'Edit Product' : 'Add Product'}</h3>
              <button className="modal-close" onClick={closeModal}>×</button>
            </div>
            <div className="modal-body">
              {error && (
                <div style={{ background: 'var(--danger-light)', color: 'var(--danger)', padding: '8px 12px', borderRadius: 6, marginBottom: 12, fontSize: 13 }}>
                  {error}
                </div>
              )}
              <div className="form-grid">
                <div className="form-field">
                  <label>Product Name *</label>
                  <input type="text" value={form.name} onChange={(e) => handleField('name', e.target.value)} placeholder="e.g. Silk Saree" autoFocus />
                </div>
                <div className="form-row">
                  <div className="form-field">
                    <label>Category</label>
                    <input type="text" value={form.category} onChange={(e) => handleField('category', e.target.value)} placeholder="e.g. Clothing" />
                  </div>
                  <div className="form-field">
                    <label>Price (₹) *</label>
                    <input type="number" min="0" step="0.01" value={form.price} onChange={(e) => handleField('price', e.target.value)} placeholder="0.00" />
                  </div>
                </div>
                <div className="form-row">
                  <div className="form-field">
                    <label>Unit</label>
                    <select value={form.unit} onChange={(e) => handleField('unit', e.target.value)}>
                      {UNITS.map((u) => <option key={u} value={u}>{u}</option>)}
                    </select>
                  </div>
                  <div className="form-field">
                    <label>GST Rate</label>
                    <select value={form.gstRate} onChange={(e) => handleField('gstRate', e.target.value)}>
                      {GST_RATES.map((r) => <option key={r} value={r}>{r}%</option>)}
                    </select>
                  </div>
                </div>
              </div>
            </div>
            <div className="modal-footer">
              <button className="btn btn-ghost" onClick={closeModal}>Cancel</button>
              <button className="btn btn-primary" onClick={handleSave}>{editingProduct ? 'Update' : 'Add Product'}</button>
            </div>
          </div>
        </div>
      )}

      {qrProduct && (
        <div className="modal-overlay" onClick={() => setQrProduct(null)}>
          <div className="modal" style={{ maxWidth: 320 }} onClick={(e) => e.stopPropagation()}>
            <div className="modal-header">
              <h3>QR Label</h3>
              <button className="modal-close" onClick={() => setQrProduct(null)}>×</button>
            </div>
            <div className="modal-body" style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 16, padding: '24px 20px' }}>
              <div style={{ border: '2px solid var(--border)', borderRadius: 12, padding: '20px 24px', textAlign: 'center', background: '#fff', width: '100%', maxWidth: 260 }}>
                {qrProduct.category && (
                  <div style={{ fontSize: 10, textTransform: 'uppercase', letterSpacing: 1, color: 'var(--text-muted)', marginBottom: 6 }}>{qrProduct.category}</div>
                )}
                <div style={{ fontWeight: 700, fontSize: 15, marginBottom: 4, lineHeight: 1.3 }}>{qrProduct.name}</div>
                <div style={{ fontSize: 22, fontWeight: 800, color: 'var(--green-dark)', marginBottom: 4 }}>₹{qrProduct.price.toFixed(2)}</div>
                <div style={{ fontSize: 11, color: 'var(--text-muted)', marginBottom: 14 }}>per {qrProduct.unit} · GST {qrProduct.gstRate}%</div>
                <div style={{ display: 'flex', justifyContent: 'center' }}>
                  <QRCodeSVG value={qrData(qrProduct)} size={140} level="M" style={{ borderRadius: 4 }} />
                </div>
              </div>
              <p style={{ fontSize: 12, color: 'var(--text-muted)', textAlign: 'center' }}>Scan to view product details</p>
            </div>
            <div className="modal-footer">
              <button className="btn btn-ghost" onClick={() => setQrProduct(null)}>Close</button>
              <button className="btn btn-primary" onClick={() => window.print()}>🖨️ Print Label</button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};

export default Products;
