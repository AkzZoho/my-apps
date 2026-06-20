import React from 'react';
import type { Screen } from '../types';

interface SidebarProps {
  screen: Screen;
  onNav: (s: Screen) => void;
  shopName: string;
  onEditShopName: () => void;
}

const DAYS = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
const MONTHS = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

function formatDate(date: Date): string {
  const day = DAYS[date.getDay()];
  const d = date.getDate();
  const month = MONTHS[date.getMonth()];
  const year = date.getFullYear();
  return `${day}, ${d} ${month} ${year}`;
}

const NAV_ITEMS: { screen: Screen; icon: string; label: string }[] = [
  { screen: 'pos', icon: '🧾', label: 'POS' },
  { screen: 'products', icon: '📦', label: 'Products' },
  { screen: 'history', icon: '📋', label: 'History' },
];

const Sidebar: React.FC<SidebarProps> = ({ screen, onNav, shopName, onEditShopName }) => {
  const today = formatDate(new Date());

  return (
    <aside className="sidebar">
      <div className="sidebar-brand" onClick={onEditShopName} style={{ cursor: 'pointer' }} title="Click to edit shop name">
        <h2>{shopName}</h2>
        <p>Billing Software</p>
      </div>

      <nav className="sidebar-nav">
        {NAV_ITEMS.map((item) => (
          <button
            key={item.screen}
            className={`nav-btn${screen === item.screen ? ' active' : ''}`}
            onClick={() => onNav(item.screen)}
          >
            <span className="icon">{item.icon}</span>
            {item.label}
          </button>
        ))}
      </nav>

      <div className="sidebar-footer">
        <span className="date-str">{today}</span>
      </div>
    </aside>
  );
};

export default Sidebar;
