import React from 'react';
import type { Bill } from '../types';
import { storage } from '../storage';
import BillView from './BillView';

interface BillHistoryProps {
  bills: Bill[];
  onDelete: (id: string) => void;
}

const MONTHS = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

function formatDateShort(isoString: string): string {
  const date = new Date(isoString);
  return `${date.getDate()} ${MONTHS[date.getMonth()]} ${date.getFullYear()}`;
}

const BillHistory: React.FC<BillHistoryProps> = ({ bills, onDelete }) => {
  const [search, setSearch] = React.useState('');
  const [selectedBill, setSelectedBill] = React.useState<Bill | null>(null);
  const [shopName] = React.useState(() => storage.getShopName());

  const filtered = React.useMemo(() => {
    const q = search.trim().toLowerCase();
    if (!q) return bills;
    return bills.filter(
      (b) => b.billNumber.toLowerCase().includes(q) || b.customerName.toLowerCase().includes(q)
    );
  }, [bills, search]);

  function handleDelete(e: React.MouseEvent, id: string) {
    e.stopPropagation();
    if (window.confirm('Delete this bill permanently?')) {
      onDelete(id);
      if (selectedBill?.id === id) setSelectedBill(null);
    }
  }

  return (
    <div className="screen">
      <div className="screen-header">
        <div className="screen-header-text">
          <h2>Bill History</h2>
          <p>{bills.length} bill{bills.length !== 1 ? 's' : ''} recorded</p>
        </div>
      </div>

      <div className="history-filters">
        <input
          className="search-input"
          type="text"
          placeholder="Search by bill number or customer name..."
          value={search}
          onChange={(e) => setSearch(e.target.value)}
        />
      </div>

      {bills.length === 0 ? (
        <div className="no-bills">No bills yet. Create your first bill from POS.</div>
      ) : filtered.length === 0 ? (
        <div className="no-bills">No bills match your search.</div>
      ) : (
        <div className="bill-list">
          {filtered.map((bill) => (
            <div key={bill.id} className="bill-card" onClick={() => setSelectedBill(bill)}>
              <span className="bill-num">{bill.billNumber}</span>
              <div className="bill-details">
                <span className="bill-customer">{bill.customerName || 'Walk-in Customer'}</span>
                <span className="bill-meta-text">
                  {formatDateShort(bill.date)} &middot; {bill.items.length} item{bill.items.length !== 1 ? 's' : ''}
                </span>
              </div>
              <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'flex-end', gap: 6 }}>
                <span className="bill-total">₹{bill.grandTotal.toFixed(2)}</span>
                <span className={`pay-chip ${bill.paymentMode}`}>{bill.paymentMode.toUpperCase()}</span>
                <button className="icon-btn del" onClick={(e) => handleDelete(e, bill.id)} title="Delete">🗑️</button>
              </div>
            </div>
          ))}
        </div>
      )}

      {selectedBill && (
        <BillView bill={selectedBill} shopName={shopName} onClose={() => setSelectedBill(null)} />
      )}
    </div>
  );
};

export default BillHistory;
