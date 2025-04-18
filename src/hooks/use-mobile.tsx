
import { useEffect, useState } from 'react';
import { useMediaQuery } from 'react-responsive';

export function useMobile() {
  const [isMounted, setIsMounted] = useState(false);
  const isMobileQuery = useMediaQuery({ maxWidth: 768 });
  const isTabletQuery = useMediaQuery({ minWidth: 769, maxWidth: 1024 });
  
  // Avoid hydration mismatch by only returning the value after mounting
  const isMobile = isMounted ? isMobileQuery : false;
  const isTablet = isMounted ? isTabletQuery : false;

  useEffect(() => {
    setIsMounted(true);
  }, []);

  return { isMobile, isTablet, isMounted };
}