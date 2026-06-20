import { useState, useEffect } from 'react';
import { storage } from './storage';
import type { Product, Screen } from './types';
import Sidebar from './components/Sidebar';
import POS from './components/POS';
import Products from './components/Products';
import BillHistory from './components/BillHistory';
import './index.css';

export default function App() {
  const [screen, setScreen] = useState<Screen>('pos');
  const [products, setProducts] = useState<Product[]>([]);
  const [shopName, setShopName] = useState(storage.getShopName());
  const [editingShop, setEditingShop] = useState(false);
  const [shopInput, setShopInput] = useState('');

  useEffect(() => {
    setProducts(storage.getProducts());
  }, []);

  function handleProductsUpdate(updated: Product[]) {
    storage.saveProducts(updated);
    setProducts(updated);
  }

  function handleShopNameSave() {
    const name = shopInput.trim() || 'My Shop';
    storage.setShopName(name);
    setShopName(name);
    setEditingShop(false);
  }

  return (
    <>
      <Sidebar
        screen={screen}
        onNav={setScreen}
        shopName={shopName}
        onEditShopName={() => { setShopInput(shopName); setEditingShop(true); }}
      />
      <div className="main">
        <div className="screen">
          {screen === 'pos' && (
            <POS products={products} onBillSaved={() => {}} />
          )}
          {screen === 'products' && (
            <Products products={products} onUpdate={handleProductsUpdate} />
          )}
          {screen === 'history' && (
            <BillHistory bills={storage.getBills()} onDelete={(id) => {
              storage.deleteBill(id);
            }} />
          )}
        </div>
      </div>

      {editingShop && (
        <div className="modal-overlay" onClick={() => setEditingShop(false)}>
          <div className="modal" style={{ maxWidth: 360 }} onClick={e => e.stopPropagation()}>
            <div className="modal-header">
              <h3>Shop Name</h3>
              <button className="modal-close" onClick={() => setEditingShop(false)}>×</button>
            </div>
            <div className="modal-body">
              <div className="form-field">
                <label>Shop Name</label>
                <input
                  autoFocus
                  value={shopInput}
                  onChange={e => setShopInput(e.target.value)}
                  onKeyDown={e => e.key === 'Enter' && handleShopNameSave()}
                  placeholder="Enter your shop name"
                />
              </div>
            </div>
            <div className="modal-footer">
              <button className="btn btn-ghost" onClick={() => setEditingShop(false)}>Cancel</button>
              <button className="btn btn-primary" onClick={handleShopNameSave}>Save</button>
            </div>
          </div>
        </div>
      )}
    </>
  );
}
