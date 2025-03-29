'use client'
import { Box, Typography } from "@mui/material"
import { ConnectButton } from "@rainbow-me/rainbowkit"
import Link from "next/link"
import { usePathname } from "next/navigation"

const Header = () => {
  const Links = [
    {
      name: 'Stake',
      path: '/'
    },
    {
      name: 'Withdrawal',
      path: '/withdraw'
    }
  ]
  const pathname = usePathname()
  return (
    <Box sx={{
      display: 'flex',
      justifyContent: 'space-between',
      alignItems: 'center',
      p: '10px 40px',
      borderBottom: '1px solid #888'
    }}>
      <Box>MetaNode Stake</Box>
      <Box display={'flex'} alignItems={'center'} gap={'20px'}>
        <Box display={'flex'}>
          {
            Links.map(link => {
              const active = (pathname === link.path || pathname === link.path + '/');
              return (
                <Typography
                  key={link.name}
                  className='default-menu hvr-grow'
                  sx={{
                    mx: '15px',
                    fontWeight: active ? '700' : '400',
                    fontSize: '20px',
                    textTransform: 'none',
                    '&:before': {
                      content: '""',
                      display: active ? 'inline-block' : 'none',
                      verticalAlign: 'middle',
                      mr: '3px',
                      width: '5px',
                      height: '5px',
                      borderRadius: '10px',
                      background: '#000',
                      fontSize: '20px'
                    }
                  }}
                >
                  <Link style={{ cursor: link.path === '#' ? 'not-allowed' : 'pointer' }} href={link.path}>{link.name}</Link>
                </Typography>
              )
            })
          }
        </Box>

        <ConnectButton></ConnectButton>
      </Box>
    </Box>
  )
}

export default Header