import { useState, useEffect, createContext, useContext } from 'react';
import { Receipt, Package, ShoppingBag, BarChart2, Settings2, WifiOff } from 'lucide-react';
import { onAuthStateChanged, signOut, type User } from 'firebase/auth';
import { auth } from './lib/firebase';
import * as db from './lib/db';
import type { Bill, Product, Purchase, Screen, ShopInfo } from './types';
import Sidebar from './components/Sidebar';
import POS from './components/POS';
import Products from './components/Products';
import ReportsScreen from './components/ReportsScreen';
import PurchaseScreen from './components/PurchaseScreen';
import Settings from './components/Settings';
import AuthScreen from './components/AuthScreen';
import './index.css';

// ── Shop context ──────────────────────────────────────────────
export const ShopContext = createContext<ShopInfo>({
  name: 'My Shop', address: '', gstin: '', phone: '', operatorName: '', logo: '',
});
export const useShop = () => useContext(ShopContext);

const BOTTOM_NAV: { id: Screen; Icon: React.FC<{ size: number }>; label: string }[] = [
  { id: 'pos',      Icon: Receipt,     label: 'POS' },
  { id: 'products', Icon: Package,     label: 'Products' },
  { id: 'purchase', Icon: ShoppingBag, label: 'Purchase' },
  { id: 'reports',  Icon: BarChart2,   label: 'Reports' },
  { id: 'settings', Icon: Settings2,   label: 'Settings' },
];

const DEFAULT_SHOP: ShopInfo = { name: 'My Shop', address: '', gstin: '', phone: '', operatorName: '', logo: '' };

export default function App() {
  const [authLoading, setAuthLoading] = useState(true);
  const [user, setUser] = useState<User | null>(null);
  const [shopId, setShopId] = useState('');
  const [shopInfo, setShopInfo] = useState<ShopInfo>(DEFAULT_SHOP);
  const [products, setProducts] = useState<Product[]>([]);
  const [bills, setBills] = useState<Bill[]>([]);
  const [purchases, setPurchases] = useState<Purchase[]>([]);
  const [operators, setOperators] = useState<string[]>([]);
  const [units, setUnits] = useState<string[]>([]);
  const [isOnline, setIsOnline] = useState(navigator.onLine);
  const [screen, setScreen] = useState<Screen>(() => {
    const s = localStorage.getItem('pos_screen');
    return (['products', 'purchase', 'history', 'reports', 'settings'].includes(s ?? '')) ? s as Screen : 'pos';
  });

  // ── Auth ─────────────────────────────────────────────────────
  useEffect(() => {
    return onAuthStateChanged(auth, (u) => {
      setUser(u);
      if (u) {
        loadShopData(u.uid);
      } else {
        setAuthLoading(false);
        setShopId('');
      }
    });
  }, []); // eslint-disable-line react-hooks/exhaustive-deps

  // ── Online/offline banner ─────────────────────────────────────
  useEffect(() => {
    const onOnline  = () => setIsOnline(true);
    const onOffline = () => setIsOnline(false);
    window.addEventListener('online',  onOnline);
    window.addEventListener('offline', onOffline);
    return () => {
      window.removeEventListener('online',  onOnline);
      window.removeEventListener('offline', onOffline);
    };
  }, []);

  async function loadShopData(userId: string) {
    try {
      let shop = await db.getShop(userId);
      if (!shop) shop = await db.createShop(userId);

      localStorage.setItem(`pos_shopid_${userId}`, shop.id);
      setShopId(shop.id);

      const activeOp = localStorage.getItem(`pos_operator_${shop.id}`) ?? '';
      setShopInfo({ ...shop.info, operatorName: activeOp || shop.info.operatorName });

      const [prods, ops, bls, purs, uns] = await Promise.all([
        db.getProducts(shop.id),
        db.getOperators(shop.id),
        db.getBills(shop.id),
        db.getPurchases(shop.id),
        db.getUnits(shop.id),
      ]);

      setProducts(prods);
      setOperators(ops);
      setBills(bls);
      setPurchases(purs);
      setUnits(uns);

    } catch (e) {
      console.error('loadShopData error:', e);
    } finally {
      setAuthLoading(false);
    }
  }

  // ── Mutations ─────────────────────────────────────────────────

  async function handleProductsUpdate(updated: Product[]) {
    setProducts(updated);
    if (shopId) await db.saveProducts(shopId, updated);
  }

  async function handleUnitsUpdate(updated: string[]) {
    setUnits(updated);
    if (shopId) await db.saveUnits(shopId, updated);
  }

  function handleAddUnit(unit: string) {
    const trimmed = unit.trim();
    if (!trimmed || units.includes(trimmed)) return;
    handleUnitsUpdate([...units, trimmed]);
  }

  async function handleNextBillNumber(): Promise<string> {
    try {
      return await db.nextBillNumber(shopId);
    } catch {
      return `BILL-${String(bills.length + 1).padStart(4, '0')}`;
    }
  }

  async function handleBillSaved(bill: Bill) {
    setBills(prev => [bill, ...prev]);
    if (shopId) await db.saveBill(shopId, bill);
    const updatedProducts = products.map(p => {
      if (p.stock === undefined) return p;
      const billItem = bill.items.find(i => i.productId === p.id);
      if (!billItem) return p;
      return { ...p, stock: Math.max(0, p.stock - billItem.quantity) };
    });
    setProducts(updatedProducts);
    if (shopId) await db.saveProducts(shopId, updatedProducts);
  }

  async function handleBillDelete(id: string) {
    setBills(prev => prev.filter(b => b.id !== id));
    if (shopId) await db.deleteBill(shopId, id);
  }

  async function handleNextPurchaseNumber(): Promise<string> {
    try {
      return await db.nextPurchaseNumber(shopId);
    } catch {
      return `PR-${String(purchases.length + 1).padStart(4, '0')}`;
    }
  }

  async function handlePurchaseSave(purchase: Purchase) {
    setPurchases(prev => [purchase, ...prev]);
    if (shopId) await db.savePurchase(shopId, purchase);
  }

  async function handlePurchaseDelete(id: string) {
    setPurchases(prev => prev.filter(p => p.id !== id));
    if (shopId) await db.deletePurchase(shopId, id);
  }

  async function handlePurchaseStatusUpdate(id: string, status: 'pending' | 'received') {
    setPurchases(prev => prev.map(p => p.id === id ? { ...p, status } : p));
    if (shopId) await db.updatePurchaseStatus(shopId, id, status);
    if (status === 'received') {
      const purchase = purchases.find(p => p.id === id);
      if (purchase) {
        const updatedProducts = products.map(p => {
          if (p.stock === undefined) return p;
          const item = purchase.items.find(i => i.productId === p.id);
          if (!item) return p;
          return { ...p, stock: p.stock + item.quantity };
        });
        setProducts(updatedProducts);
        if (shopId) await db.saveProducts(shopId, updatedProducts);
      }
    }
  }

  async function handleSettingsSave(info: ShopInfo, ops: string[]) {
    setShopInfo(info);
    setOperators(ops);
    if (shopId) {
      await db.updateShop(shopId, info);
      await db.saveOperators(shopId, ops);
    }
  }

  function handleOperatorChange(name: string) {
    if (shopId) localStorage.setItem(`pos_operator_${shopId}`, name);
    setShopInfo(prev => ({ ...prev, operatorName: name }));
  }

  function navigate(to: Screen) {
    setScreen(to);
    localStorage.setItem('pos_screen', to);
    window.scrollTo(0, 0);
  }

  async function handleSignOut() {
    await signOut(auth);
    setUser(null);
    setShopId('');
    setBills([]);
    setProducts([]);
    setPurchases([]);
    setOperators([]);
    setUnits([]);
    setShopInfo(DEFAULT_SHOP);
  }

  // ── Loading / Auth screens ────────────────────────────────────

  if (authLoading) {
    return (
      <div style={{ position: 'fixed', inset: 0, display: 'flex', alignItems: 'center', justifyContent: 'center', background: 'var(--bg)' }}>
        <div className="auth-spinner" />
      </div>
    );
  }

  if (!user) return <AuthScreen />;

  return (
    <ShopContext.Provider value={shopInfo}>
      {!isOnline && (
        <div className="sync-banner offline">
          <WifiOff size={14} />
          Offline — bills are saved locally and will sync when reconnected
        </div>
      )}

      <Sidebar
        screen={screen}
        onNav={navigate}
        shopInfo={shopInfo}
        onEditSettings={() => navigate('settings')}
        onSignOut={handleSignOut}
      />

      <div className={`main${!isOnline ? ' has-banner' : ''}`}>
        <div className="screen">
          {screen === 'pos' && (
            <POS
              products={products}
              bills={bills}
              operators={operators}
              operatorName={shopInfo.operatorName}
              onOperatorChange={handleOperatorChange}
              nextBillNumber={handleNextBillNumber}
              onBillSaved={handleBillSaved}
            />
          )}
          {screen === 'products' && (
            <Products
              products={products}
              onUpdate={handleProductsUpdate}
              units={units}
              onAddUnit={handleAddUnit}
            />
          )}
          {screen === 'purchase' && (
            <PurchaseScreen
              purchases={purchases}
              products={products}
              nextPurchaseNumber={handleNextPurchaseNumber}
              onSave={handlePurchaseSave}
              onDelete={handlePurchaseDelete}
              onStatusUpdate={handlePurchaseStatusUpdate}
              units={units}
              onAddUnit={handleAddUnit}
            />
          )}
          {(screen === 'history' || screen === 'reports') && (
            <ReportsScreen bills={bills} products={products} onDelete={handleBillDelete} />
          )}
          {screen === 'settings' && (
            <Settings
              shopInfo={shopInfo}
              shopId={shopId}
              operators={operators}
              units={units}
              onSave={handleSettingsSave}
              onUnitsChange={handleUnitsUpdate}
            />
          )}
        </div>
      </div>

      <nav className="bottom-nav">
        {BOTTOM_NAV.map(({ id, Icon, label }) => (
          <button key={id} className={`bottom-nav-btn${screen === id ? ' active' : ''}`} onClick={() => navigate(id)}>
            <span className="bn-icon"><Icon size={22} /></span>
            {label}
          </button>
        ))}
      </nav>

    </ShopContext.Provider>
  );
}
