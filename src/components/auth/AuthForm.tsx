
import { useState } from 'react';
import { useAuth } from '../../context/AuthContext';
import { Button } from '../ui/button';
import { Input } from '../ui/input';
import { Card, CardContent, CardDescription, CardFooter, CardHeader, CardTitle } from '../ui/card';
import { Tabs, TabsContent, TabsList, TabsTrigger } from '../ui/tabs';
import { Label } from '../ui/label';
import { cn } from '../../lib/utils';

export function AuthForm() {
  const [mode, setMode] = useState<'signin' | 'signup' | 'reset'>('signin');
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [loading, setLoading] = useState(false);
  const { signIn, signUp, resetPassword } = useAuth();

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setLoading(true);

    try {
      if (mode === 'signin') {
        await signIn(email, password);
      } else if (mode === 'signup') {
        await signUp(email, password);
      } else if (mode === 'reset') {
        await resetPassword(email);
        setMode('signin');
      }
    } catch (error) {
      console.error('Authentication error:', error);
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="flex justify-center items-center min-h-screen bg-background">
      <Card className="w-full max-w-md mx-4 shadow-lg">
        <CardHeader className="space-y-1">
          <CardTitle className="text-2xl font-bold text-center">
            {mode === 'signin' ? 'Sign In' : mode === 'signup' ? 'Create an Account' : 'Reset Password'}
          </CardTitle>
          <CardDescription className="text-center">
            {mode === 'signin' 
              ? 'Enter your email and password to sign in to your account' 
              : mode === 'signup' 
                ? 'Enter your email and password to create a new account'
                : 'Enter your email to receive a password reset link'}
          </CardDescription>
        </CardHeader>
        <form onSubmit={handleSubmit}>
          <CardContent className="space-y-4">
            {mode !== 'reset' && (
              <Tabs defaultValue="email" className="w-full">
                <TabsList className="grid w-full grid-cols-1">
                  <TabsTrigger value="email">Email</TabsTrigger>
                </TabsList>
                <TabsContent value="email" className="space-y-4">
                  <div className="space-y-2">
                    <Label htmlFor="email">Email</Label>
                    <Input
                      id="email"
                      type="email"
                      placeholder="name@example.com"
                      value={email}
                      onChange={(e) => setEmail(e.target.value)}
                      required
                    />
                  </div>
                  <div className="space-y-2">
                    <div className="flex items-center justify-between">
                      <Label htmlFor="password">Password</Label>
                      {mode === 'signin' && (
                        <Button 
                          type="button" 
                          variant="link" 
                          className="px-0 font-normal text-primary"
                          onClick={() => setMode('reset')}
                        >
                          Forgot password?
                        </Button>
                      )}
                    </div>
                    <Input
                      id="password"
                      type="password"
                      placeholder="••••••••"
                      value={password}
                      onChange={(e) => setPassword(e.target.value)}
                      required
                    />
                  </div>
                </TabsContent>
              </Tabs>
            )}

            {mode === 'reset' && (
              <div className="space-y-2">
                <Label htmlFor="email">Email</Label>
                <Input
                  id="email"
                  type="email"
                  placeholder="name@example.com"
                  value={email}
                  onChange={(e) => setEmail(e.target.value)}
                  required
                />
              </div>
            )}
          </CardContent>
          <CardFooter className="flex flex-col space-y-4">
            <Button 
              type="submit" 
              className="w-full bg-primary hover:bg-primary/90"
              disabled={loading}
            >
              {loading ? 'Loading...' : mode === 'signin' ? 'Sign In' : mode === 'signup' ? 'Sign Up' : 'Send Reset Link'}
            </Button>
            
            <div className="text-center text-sm">
              {mode === 'signin' ? (
                <div className="flex items-center justify-center space-x-1">
                  <span>Don't have an account?</span>
                  <Button 
                    type="button" 
                    variant="link" 
                    className="px-0 font-normal"
                    onClick={() => setMode('signup')}
                  >
                    Sign up
                  </Button>
                </div>
              ) : mode === 'signup' ? (
                <div className="flex items-center justify-center space-x-1">
                  <span>Already have an account?</span>
                  <Button 
                    type="button" 
                    variant="link" 
                    className="px-0 font-normal"
                    onClick={() => setMode('signin')}
                  >
                    Sign in
                  </Button>
                </div>
              ) : (
                <Button 
                  type="button" 
                  variant="link" 
                  className="px-0 font-normal"
                  onClick={() => setMode('signin')}
                >
                  Back to sign in
                </Button>
              )}
            </div>
          </CardFooter>
        </form>
      </Card>
    </div>
  );
}